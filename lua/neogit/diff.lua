local M = {}
local a = require("neogit.async")
local MappingsManager = require("neogit.lib.mappings_manager")

local state = {
  open = false,
  lhs = nil,
  rhs = nil
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
      if state.lhs.on_save() then
        M.close()
      else
        vim.bo.buftype = "nofile"
      end
    end)
  end
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

function M.open(lhs_info, rhs_info)
  if state.open then
    return
  end

  state.open = true

  local vim_height = vim.api.nvim_eval [[&lines]]
  local vim_width = vim.api.nvim_eval [[&columns]]

  local width = math.floor(vim_width * 0.4)
  local height = math.floor(vim_height * 0.7)
  local col = vim_width * 0.1
  local row = vim_height * 0.15

  local lhs_buf = vim.api.nvim_create_buf(false, true)
  local lhs_mmanager = MappingsManager.new(lhs_buf)
  local lhs_win = vim.api.nvim_open_win(lhs_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    border = { "┌", "─", "─", " ", "─", "─", "└", "│" }
  })

  vim.api.nvim_buf_set_lines(lhs_buf, 0, -1, false, lhs_info.lines)

  for key, _ in pairs(M.mappings.lhs) do
    lhs_mmanager.map("n", key, M.mappings.lhs[key])
  end

  lhs_mmanager.register()

  state.lhs = { buf = lhs_buf, win = lhs_win, mmanager = lhs_mmanager, on_save = lhs_info.on_save or function()end }

  local col = col + width + 1

  local rhs_buf = vim.api.nvim_create_buf(false, true)
  local rhs_mmanager = MappingsManager.new(rhs_buf)
  local rhs_win = vim.api.nvim_open_win(rhs_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    border = { "─", "─", "┐", "│", "┘", "─", "─", " " }
  })

  vim.api.nvim_buf_set_lines(rhs_buf, 0, -1, false, rhs_info.lines)
  vim.bo.readonly = true
  vim.bo.modifiable = false

  for key, _ in pairs(M.mappings.rhs) do
    rhs_mmanager.map("n", key, M.mappings.rhs[key])
  end

  rhs_mmanager.register()

  state.rhs = { buf = rhs_buf, win = rhs_win, mmanager = rhs_mmanager }

  -- Have to defer this, else the rhs window disappears ??? like what the fuck
  vim.defer_fn(function()
    vim.api.nvim_set_current_win(rhs_win)
    vim.cmd [[diffthis]]
    vim.api.nvim_set_current_win(lhs_win)
    vim.cmd [[diffthis]]
  end, 1)
end

M.mappings = {
  lhs = {
    ["q"] = M.close,
    ["<c-s>"] = M.save_lhs,
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




