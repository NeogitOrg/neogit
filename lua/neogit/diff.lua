local M = {}
local a = require("neogit.async")

local state = {
  open = false,
  lhs = nil,
  rhs = nil
}

M.state = state

function M.invoke_mapping(name, mode, key)
  M.mappings[name][mode .. " " .. key]()
end

function M.close()
  if state.lhs ~= nil then
    vim.api.nvim_buf_call(state.lhs.buf, function()
      vim.cmd [[au! * <buffer>]]
    end)
    vim.api.nvim_win_close(state.lhs.win, false)
    state.lhs = nil
  end
  if state.rhs ~= nil then
    vim.api.nvim_buf_call(state.rhs.buf, function()
      vim.cmd [[au! * <buffer>]]
    end)
    vim.api.nvim_win_close(state.rhs.win, false)
    state.rhs = nil
  end
  state.open = false
end

M.open = a.sync(function(lhs_info, rhs_info)
  if state.open then
    return
  end

  state.open = true

  a.wait_for_textlock()
  local vim_height = vim.api.nvim_eval [[&lines]]
  local vim_width = vim.api.nvim_eval [[&columns]]

  local width = math.floor(vim_width * 0.4)
  local height = math.floor(vim_height * 0.7)
  local col = vim_width * 0.1
  local row = vim_height * 0.15

  local lhs_buf = vim.api.nvim_create_buf(false, true)
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
    local tokens = vim.split(key, " ")
    local mode = tokens[1]
    local lhs = tokens[2]

    vim.api.nvim_buf_set_keymap(
      lhs_buf, 
      mode, 
      lhs, 
      string.format([[:lua require("neogit.diff").invoke_mapping('%s', '%s', '%s')<CR>]], "lhs", mode, lhs),
      {}
    )
  end

  state.lhs = { buf = lhs_buf, win = lhs_win }

  local col = col + width + 1

  local rhs_buf = vim.api.nvim_create_buf(false, true)
  local rhs_win = vim.api.nvim_open_win(rhs_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    border = { "─", "─", "┐", "│", "┘", "─", "─", " " }
  })

  vim.api.nvim_buf_set_lines(rhs_buf, 0, -1, false, rhs_info.lines)

  for key, _ in pairs(M.mappings.rhs) do
    local tokens = vim.split(key, " ")
    local mode = tokens[1]
    local lhs = tokens[2]

    vim.api.nvim_buf_set_keymap(
      rhs_buf, 
      mode, 
      lhs, 
      string.format([[:lua require("neogit.diff").invoke_mapping('%s', '%s', '%s')<CR>]], "rhs", mode, lhs),
      {}
    )
  end

  state.rhs = { buf = rhs_buf, win = rhs_win }

  -- Have to defer this, else the rhs window disappears ??? like what the fuck
  a.wait_for_textlock()
  vim.defer_fn(function()
    vim.api.nvim_set_current_win(rhs_win)
    vim.cmd [[diffthis]]
    vim.api.nvim_set_current_win(lhs_win)
    vim.cmd [[diffthis]]
  end, 1)
end)

M.mappings = {
  lhs = {
    ["n q"] = M.close
  },
  rhs = {
    ["n q"] = M.close
  },
}

D = M

return M
