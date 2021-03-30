package.loaded['neogit.buffer'] = nil

local mappings_manager = require("neogit.lib.mappings_manager")

local Buffer = {
  handle = nil,
}
Buffer.__index = Buffer

function Buffer:new(handle)
  local this = {
    handle = handle,
    border = nil,
    mmanager = mappings_manager.new()
  }

  setmetatable(this, self)

  return this
end

function Buffer:focus()
  local windows = vim.fn.win_findbuf(self.handle)

  if #windows == 0 then
    return
  end

  vim.fn.win_gotoid(windows[1])
end

function Buffer:lock()
  self:set_option("readonly", true)
  self:set_option("modifiable", false)
end

function Buffer:define_autocmd(events, script)
  vim.cmd(string.format("au %s <buffer=%d> %s", events, self.handle, script))
end

function Buffer:clear()
  vim.api.nvim_buf_set_lines(self.handle, 0, -1, false, {})
end

function Buffer:get_lines(first, last, strict)
  return vim.api.nvim_buf_get_lines(self.handle, first, last, strict)
end

function Buffer:set_lines(first, last, strict, lines)
  vim.api.nvim_buf_set_lines(self.handle, first, last, strict, lines)
end

function Buffer:move_cursor(line)
  if line < 0 then
    self:focus()
    vim.cmd("norm G")
  else
    self:focus()
    vim.cmd("norm " .. line .. "G")
  end
end

function Buffer:close(force)
  if force == nil then
    force = false
  end
  vim.api.nvim_buf_delete(self.handle, { force = force })
  if self.border_buffer then
    vim.api.nvim_buf_delete(self.border_buffer, {})
  end
end

function Buffer:put(lines, after, follow)
  self:focus()
  vim.api.nvim_put(lines, "l", after, follow)
end

function Buffer:create_fold(first, last)
  vim.cmd(string.format(self.handle .. "bufdo %d,%dfold", first, last))
end

function Buffer:unlock()
  self:set_option("readonly", false)
  self:set_option("modifiable", true)
end

function Buffer:get_option(name)
  vim.api.nvim_buf_get_option(self.handle, name)
end

function Buffer:set_option(name, value)
  vim.api.nvim_buf_set_option(self.handle, name, value)
end

function Buffer:set_name(name)
  vim.api.nvim_buf_set_name(self.handle, name)
end

function Buffer:set_foldlevel(level)
  vim.cmd("setlocal foldlevel=" .. level)
end

function Buffer:open_fold(line, reset_pos)
  local pos
  if reset_pos == true then
    pos = vim.fn.getpos()
  end

  vim.fn.setpos('.', {self.handle, line, 0, 0})
  vim.cmd('normal zo')

  if reset_pos == true then
    vim.fn.setpos('.', pos)
  end
end

function Buffer:place_sign(line, name, group, id)
  -- Sign IDs should be unique within a group, however there's no downside as
  -- long as we don't want to uniquely identify the placed sign later. Thus,
  -- we leave the choice to the caller
  local sign_id = id or 1

  -- There's an equivalent function sign_place() which can automatically use
  -- a free ID, but is considerable slower, so we use the command for now
  local cmd = 'sign place '..sign_id..' line='..line..' name='..name
  if group ~= nil then
    cmd = cmd..' group='..group
  end
  cmd = cmd..' buffer='..self.handle

  vim.cmd(cmd)
  return sign_id
end

function Buffer:get_sign_at_line(line, group)
  group = group or "*"
  return vim.fn.sign_getplaced(self.handle, {
    group = group,
    lnum = line
  })[1]
end

function Buffer:clear_sign_group(group)
  vim.cmd('sign unplace * group='..group..' buffer='..self.handle)
end

function Buffer:set_filetype(ft)
  vim.cmd("setlocal filetype=" .. ft)
end

function Buffer:call(f)
  vim.api.nvim_buf_call(self.handle, f)
end

function Buffer.exists(name)
  return vim.fn.bufnr(name) ~= -1
end

function Buffer:set_extmark(...)
  return vim.api.nvim_buf_set_extmark(self.handle, ...)
end

function Buffer:get_extmark(ns, id)
  return vim.api.nvim_buf_get_extmark_by_id(self.handle, ns, id, { details = true })
end

function Buffer:del_extmark(ns, id)
  return vim.api.nvim_buf_del_extmark(self.handle, ns, id)
end

function Buffer.create(config)
  local config = config or {}
  local kind = config.kind or "split"
  local buffer = nil

  if kind == "tab" then
    vim.cmd("tabnew")
    buffer = Buffer:new(vim.api.nvim_get_current_buf())
  elseif kind == "split" then
    vim.cmd("below new")
    buffer = Buffer:new(vim.api.nvim_get_current_buf())
  elseif kind == "vsplit" then
    vim.cmd("bot vnew")
    buffer = Buffer:new(vim.api.nvim_get_current_buf())
  elseif kind == "floating" then
    -- Creates the border window
    local vim_height = vim.api.nvim_eval [[&lines]]
    local vim_width = vim.api.nvim_eval [[&columns]]
    local width = math.floor(vim_width * 0.8) + 5
    local height = math.floor(vim_height * 0.7) + 2
    local col = vim_width * 0.1 - 2
    local row = vim_height * 0.15 - 1

    local border_buffer = vim.api.nvim_create_buf(false, true)
    local border_window = vim.api.nvim_open_win(border_buffer, true, {
      relative = 'editor',
      width = width,
      height = height,
      col = col,
      row = row,
      style = 'minimal',
      focusable = false
    })

    vim.api.nvim_win_set_cursor(border_window, { 1, 0 })

    vim.wo.winhl = "Normal:Normal"

    vim.api.nvim_buf_set_lines(border_buffer, 0, 1, false, { "┌" .. string.rep('─', width - 2) .. "┐" })
    for i=2,height-1 do
      vim.api.nvim_buf_set_lines(border_buffer, i - 1, i, false, { "│" .. string.rep(' ', width - 2) .. "│"})
    end
    vim.api.nvim_buf_set_lines(border_buffer, height - 1, -1, false, { "└" .. string.rep('─', width - 2) .. "┘" })
    -- Creates the content window
    local width = width - 2 
    local height = height - 2
    local col = col + 1
    local row = row + 1

    local content_buffer = vim.api.nvim_create_buf(true, true)
    local content_window = vim.api.nvim_open_win(content_buffer, true, {
      relative = 'editor',
      width = width,
      height = height,
      col = col,
      row = row,
      style = 'minimal',
      focusable = false
    })

    vim.api.nvim_win_set_cursor(content_window, { 1, 0 })
    buffer = Buffer:new(content_buffer)
    buffer.border_buffer = border_buffer
  end

  vim.cmd("set nonu")
  vim.cmd("set nornu")

  buffer:set_name(config.name)

  buffer:set_option("bufhidden", config.bufhidden or "wipe")
  buffer:set_option("buftype", config.buftype or "nofile")
  buffer:set_option("swapfile", false)

  if config.filetype then
    buffer:set_filetype(config.filetype)
  end

  buffer.mmanager.mappings["q"] = function()
    buffer:close()
  end

  config.initialize(buffer)

  buffer.mmanager.register()

  if not config.modifiable then
    buffer:set_option("modifiable", false)
  end

  if config.readonly ~= nil and config.readonly then
    buffer:set_option("readonly", true)
  end

  -- This sets fold styling for Neogit windows without overriding user styling
  buffer:call(function()
    vim.wo.winhl = "Folded:NeogitFold"
  end)

  return buffer
end

return Buffer
