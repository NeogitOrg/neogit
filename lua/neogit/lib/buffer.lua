package.loaded['neogit.buffer'] = nil

local mappings_manager = require("neogit.lib.mappings_manager")

local Buffer = {
  handle = nil
}
Buffer.__index = Buffer

function Buffer:new(handle)
  local this = {
    handle = handle,
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

function Buffer:close()
  vim.api.nvim_buf_delete(self.handle, {})
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

function Buffer:set_filetype(ft)
  vim.cmd("setlocal filetype=" .. ft)
end

function Buffer.exists(name)
  return vim.fn.bufnr(name) ~= -1
end

function Buffer.create(config)
  local config = config or {}
  local kind = config.kind or "split"

  if kind == "tab" then
    vim.cmd("tabnew")
  elseif kind == "split" then
    vim.cmd("below new")
  elseif kind == "floating" then
    vim.api.nvim_err_writeln("Floating kind is not implemented yet")
    return nil
  end

  local buffer = Buffer:new(vim.api.nvim_get_current_buf())

  vim.cmd("set nonu")
  vim.cmd("set nornu")

  buffer:set_name(config.name)

  buffer:set_option("bufhidden", config.bufhidden or "wipe")
  buffer:set_option("buftype", config.buftype or "nofile")
  buffer:set_option("swapfile", false)

  if config.filetype then
    buffer:set_filetype(config.filetype)
  end

  if config.tab then
    buffer.mmanager.mappings["q"] = "<cmd>tabclose<CR>"
  else
    buffer.mmanager.mappings["q"] = "<cmd>q<CR>"
  end

  config.initialize(buffer)

  buffer.mmanager.register()

  if not config.modifiable then
    buffer:set_option("modifiable", false)
  end

  if config.readonly ~= nil and config.readonly then
    buffer:set_option("readonly", true)
  end

  return buffer
end

return Buffer
