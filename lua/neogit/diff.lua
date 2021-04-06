local M = {}
local a = require("neogit.async")

local state = {
  open = false,
  dec = nil,
  lhs = nil,
  rhs = nil
}

M.state = state

function M.invoke_mapping(name, mode, key)
  M.mappings[name][mode .. " " .. key]()
end

function M.close()
  if state.dec ~= nil then
    vim.api.nvim_buf_call(state.dec.buf, function()
      vim.cmd [[au! * <buffer>]]
    end)
    vim.api.nvim_win_close(state.dec.win, false)
    state.dec = nil
  end
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

  local width = math.floor(vim_width * 0.8) + 5
  local height = math.floor(vim_height * 0.7) + 2
  local col = vim_width * 0.1 - 2
  local row = vim_height * 0.15 - 1

  -- decorations setup
  local dec_buf = vim.api.nvim_create_buf(false, true)
  local dec_win = vim.api.nvim_open_win(dec_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    focusable = false
  })

  state.dec = { buf = dec_buf, win = dec_win }

  -- create decorations buffer
  vim.api.nvim_buf_set_lines(dec_buf, 0, 1, false, { "┌" .. string.rep('─', width - 2) .. "┐" })
  for i=2,height-1 do
    vim.api.nvim_buf_set_lines(dec_buf, i - 1, i, false, { "│" .. string.rep(' ', width - 2) .. "│"})
  end
  vim.api.nvim_buf_set_lines(dec_buf, height - 1, -1, false, { "└" .. string.rep('─', width - 2) .. "┘" })

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
    row = row
  })

  vim.api.nvim_buf_set_lines(lhs_buf, 0, -1, false, lhs_info.lines)
  vim.api.nvim_buf_set_name(lhs_buf, lhs_info.name)

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

  local width = math.floor(vim_width * 0.4)
  local height = math.floor(vim_height * 0.7)
  local col = vim_width * 0.1 + width + 1
  local row = vim_height * 0.15

  local rhs_buf = vim.api.nvim_create_buf(false, true)
  local rhs_win = vim.api.nvim_open_win(rhs_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row
  })

  vim.api.nvim_buf_set_lines(rhs_buf, 0, -1, false, rhs_info.lines)
  vim.api.nvim_buf_set_name(rhs_buf, rhs_info.name)

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
