local M = {}
local a = require 'plenary.async_lib'
local await, void, async, scheduler = a.await, a.void, a.async, a.scheduler
local MappingsManager = require("neogit.lib.mappings_manager")

local state = {
  open = false,
  lhs = nil,
  rhs = nil,
  display_kind = "tab", -- "floating" | "tab"
  on_save = function()end,
  go_item = function()end
}

M.state = state

function M.noop()
end

function M.focus(id)
  if state[id] then
    vim.api.nvim_set_current_win(state[id].win)
  end
end

function M.save_lhs()
  if state.open then
    vim.api.nvim_buf_call(state.lhs.buf, function()
      vim.bo.buftype = ""
      if state.on_save() then
        M.close()
      else
        vim.bo.buftype = "nofile"
      end
    end)
  end
end

M.go_file = void(async(function(inc)
  if state.open then
    local lhs, rhs = await(state.go_item(inc))

    if lhs ~= nil and rhs ~= nil then
      await(scheduler())
      vim.api.nvim_buf_call(state.lhs.buf, function()
        local ro = vim.bo.readonly
        local m = vim.bo.modifiable
        local bt = vim.bo.buftype

        vim.bo.buftype = ""
        vim.bo.modifiable = true
        vim.bo.readonly = false

        vim.api.nvim_buf_set_lines(state.lhs.buf, 0, -1, false, lhs)

        vim.bo.buftype = bt
        vim.bo.modifiable = m
        vim.bo.readonly = ro
      end)

      await(scheduler())
      vim.api.nvim_buf_call(state.rhs.buf, function()
        local ro = vim.bo.readonly
        local m = vim.bo.modifiable
        local bt = vim.bo.buftype

        vim.bo.buftype = ""
        vim.bo.modifiable = true
        vim.bo.readonly = false

        vim.api.nvim_buf_set_lines(state.rhs.buf, 0, -1, false, rhs)

        vim.bo.buftype = bt
        vim.bo.modifiable = m
        vim.bo.readonly = ro
      end)
    end
  end
end))

function M.next_file()
  M.go_file(1)
end

function M.prev_file()
  M.go_file(-1)
end

function M.focus_lhs()
  M.focus("lhs")
end

function M.focus_rhs()
  M.focus("rhs")
end

-- unused
-- closes the diff view if a different window gets focus
function M.on_win_leave()
  if state.open then
    local win = vim.api.nvim_get_current_win()
    if win ~= state.lhs.win and win ~= state.rhs.win then
      M.close()
    end
  end
end

function M.close()
  if state.lhs ~= nil then
    vim.api.nvim_buf_call(state.lhs.buf, function()
      vim.cmd [[au! * <buffer>]]
    end)
    vim.api.nvim_win_close(state.lhs.win, false)
    state.lhs.mmanager.delete()
    state.lhs = nil
  end
  if state.rhs ~= nil then
    vim.api.nvim_buf_call(state.rhs.buf, function()
      vim.cmd [[au! * <buffer>]]
    end)
    vim.api.nvim_win_close(state.rhs.win, false)
    state.rhs.mmanager.delete()
    state.rhs = nil
  end
  state.open = false
end

function open_floating_diff_window(height, width, x, y, border_kind, mappings, content, opts)
  local border = { "┌", "─", "─", " ", "─", "─", "└", "│" }

  if border_kind == "right" then
    border = { "─", "─", "┐", "│", "┘", "─", "─", " " }
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local mmanager = MappingsManager.new(buf)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = x,
    row = y,
    border = border
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  for key, _ in pairs(mappings) do
    mmanager.map("n", key, mappings[key])
  end

  mmanager.register()

  return { 
    buf = buf, 
    win = win, 
    mmanager = mmanager, 
  }
end

function M.open(opts)
  if state.open then
    return
  end

  opts.get_lhs_name = opts.get_lhs_name or function()
    return "[WORKTREE]"
  end

  opts.get_rhs_name = opts.get_rhs_name or function()
    return "[HEAD]"
  end

  state.open = true
  state.display_kind = opts.display_kind or state.display_kind
  state.on_save = opts.on_save or state.on_save
  state.go_item = opts.go_item or state.go_item

  if state.display_kind == "floating" then
    local vim_height = vim.api.nvim_eval [[&lines]]
    local vim_width = vim.api.nvim_eval [[&columns]]

    local width = math.floor(vim_width * 0.4)
    local height = math.floor(vim_height * 0.7)
    local col = vim_width * 0.1
    local row = vim_height * 0.15

    state.lhs = open_floating_diff_window(height, width, col, row, "Left", M.mappings.lhs, opts.lhs_content, opts)

    local col = col + width + 1
    state.rhs = open_floating_diff_window(height, width, col, row, "Right", M.mappings.rhs, opts.rhs_content, opts)

    vim.bo.readonly = true
    vim.bo.modifiable = false

    -- Have to defer this, else the rhs window disappears ??? like what the fuck
    vim.defer_fn(function()
      vim.api.nvim_set_current_win(state.rhs.win)
      vim.cmd [[diffthis]]
      vim.api.nvim_set_current_win(state.lhs.win)
      vim.cmd [[diffthis]]
    end, 1)
  elseif state.display_kind == "tab" then
    vim.cmd [[tabnew]]

    -- lhs setup
    state.lhs = {}
    state.lhs.buf = vim.api.nvim_get_current_buf()
    state.lhs.win = vim.api.nvim_get_current_win()
    state.lhs.mmanager = MappingsManager.new()

    vim.api.nvim_buf_set_lines(0, 0, -1, false, opts.lhs_content)
    -- vim.api.nvim_buf_set_name(0, opts.get_lhs_name())

    vim.bo.buftype = "nofile"

    for key, _ in pairs(M.mappings.lhs) do
      state.lhs.mmanager.map("n", key, M.mappings.lhs[key])
    end

    state.lhs.mmanager.register()

    vim.cmd [[diffthis]]

    vim.cmd [[vsp | enew]]

    -- rhs setup 
    state.rhs = {}
    state.rhs.buf = vim.api.nvim_get_current_buf()
    state.rhs.win = vim.api.nvim_get_current_win()
    state.rhs.mmanager = MappingsManager.new()

    vim.api.nvim_buf_set_lines(0, 0, -1, false, opts.rhs_content)
    -- vim.api.nvim_buf_set_name(0, opts.get_rhs_name())

    vim.bo.buftype = "nofile"
    vim.bo.readonly = true
    vim.bo.modifiable = false

    for key, _ in pairs(M.mappings.rhs) do
      state.rhs.mmanager.map("n", key, M.mappings.rhs[key])
    end

    state.rhs.mmanager.register()

    vim.cmd [[diffthis]]

    vim.api.nvim_set_current_win(state.lhs.win)
  end
end

M.mappings = {
  lhs = {
    ["q"] = M.close,
    ["<c-s>"] = M.save_lhs,
    ["]f"] = M.next_file,
    ["[f"] = M.prev_file,
    ["<c-w>l"] = M.focus_rhs,
    ["<c-w><c-l>"] = M.focus_rhs,
    ["<c-w>k"] = M.noop,
    ["<c-w>j"] = M.noop,
    ["<c-w>h"] = M.noop,
    ["<c-w><c-k>"] = M.noop,
    ["<c-w><c-j>"] = M.noop,
    ["<c-w><c-h>"] = M.noop,
  },
  rhs = {
    ["q"] = M.close,
    ["<c-w>h"] = M.focus_lhs,
    ["<c-w><c-h>"] = M.focus_lhs,
    ["<c-w>l"] = M.noop,
    ["<c-w>k"] = M.noop,
    ["<c-w>j"] = M.noop,
    ["<c-w><c-k>"] = M.noop,
    ["<c-w><c-j>"] = M.noop,
    ["<c-w><c-l>"] = M.noop,
  },
}

D = M

return M




