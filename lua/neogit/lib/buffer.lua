local api = vim.api
package.loaded["neogit.buffer"] = nil

__BUFFER_AUTOCMD_STORE = {}

local mappings_manager = require("neogit.lib.mappings_manager")
local Ui = require("neogit.lib.ui")

---@class Buffer
---@field handle number
---@field mmanager any
---@field ui Ui
---@field kind string
local Buffer = {
  kind = "split",
}
Buffer.__index = Buffer

---@param handle number
---@return Buffer
function Buffer:new(handle)
  local this = {
    handle = handle,
    border = nil,
    mmanager = mappings_manager.new(handle),
    kind = nil, -- how the buffer was opened. For more information look at the create function
  }

  this.ui = Ui.new(this)

  setmetatable(this, self)

  return this
end

---@return number|nil
function Buffer:focus()
  local windows = vim.fn.win_findbuf(self.handle)

  if #windows == 0 then
    return nil
  end

  vim.fn.win_gotoid(windows[1])
  return windows[1]
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

function Buffer:get_line(line)
  return vim.fn.getbufline(self.handle, line)
end

function Buffer:get_current_line()
  return self:get_line(vim.fn.getpos(".")[2])
end

function Buffer:set_lines(first, last, strict, lines)
  vim.api.nvim_buf_set_lines(self.handle, first, last, strict, lines)
end

function Buffer:set_text(first_line, last_line, first_col, last_col, lines)
  vim.api.nvim_buf_set_text(self.handle, first_line, first_col, last_line, last_col, lines)
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
  if self.kind == "tab" then
    -- `silent!` as this might throw errors if 'hidden' is disabled.
    vim.cmd("silent! 1only")
    vim.cmd("try | tabn # | catch /.*/ | tabp | endtry")
  end

  if api.nvim_buf_is_valid(self.handle) then
    vim.api.nvim_buf_delete(self.handle, { force = force })
  end
end

function Buffer:hide()
  if not self:focus() then
    return
  end

  if self.kind == "tab" then
    -- `silent!` as this might throw errors if 'hidden' is disabled.
    vim.cmd("silent! 1only")
    vim.cmd("try | tabn # | catch /.*/ | tabp | endtry")
  elseif self.kind == "replace" then
    if self.old_buf and api.nvim_buf_is_loaded(self.old_buf) then
      api.nvim_set_current_buf(self.old_buf)
    end
  else
    api.nvim_win_close(0, {})
  end
end

---@return number
function Buffer:show()
  local windows = vim.fn.win_findbuf(self.handle)

  -- Already visible
  if #windows > 0 then
    return windows[1]
  end

  local win
  local kind = self.kind

  if kind == "replace" then
    self.old_buf = api.nvim_get_current_buf()
    api.nvim_set_current_buf(self.handle)
    win = api.nvim_get_current_win()
  elseif kind == "tab" then
    vim.cmd("tabnew")
    api.nvim_set_current_buf(self.handle)
    win = api.nvim_get_current_win()
  elseif kind == "split" then
    vim.cmd("below split")
    api.nvim_set_current_buf(self.handle)
    win = api.nvim_get_current_win()
  elseif kind == "split_above" then
    vim.cmd("top split")
    api.nvim_set_current_buf(self.handle)
    win = api.nvim_get_current_win()
  elseif kind == "vsplit" then
    vim.cmd("bot vsplit")
    api.nvim_set_current_buf(self.handle)
    win = api.nvim_get_current_win()
  elseif kind == "floating" then
    -- Creates the border window
    local vim_height = vim.o.lines
    local vim_width = vim.o.columns

    local width = math.floor(vim_width * 0.8) + 3
    local height = math.floor(vim_height * 0.7)
    local col = vim_width * 0.1 - 1
    local row = vim_height * 0.15

    local content_window = vim.api.nvim_open_win(self.handle, true, {
      relative = "editor",
      width = width,
      height = height,
      col = col,
      row = row,
      style = "minimal",
      focusable = false,
      border = "single",
    })

    vim.api.nvim_win_set_cursor(content_window, { 1, 0 })
    win = content_window
  end

  vim.cmd("setlocal nonu")
  vim.cmd("setlocal nornu")

  return win
end

function Buffer:is_valid()
  return vim.api.nvim_buf_is_valid(self.handle)
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

function Buffer:replace_content_with(lines)
  self:set_lines(0, -1, false, lines)
end

function Buffer:open_fold(line, reset_pos)
  local pos
  if reset_pos == true then
    pos = vim.fn.getpos()
  end

  vim.fn.setpos(".", { self.handle, line, 0, 0 })
  vim.cmd("normal zo")

  if reset_pos == true then
    vim.fn.setpos(".", pos)
  end
end

function Buffer:add_highlight(line, col_start, col_end, name, ns_id)
  local ns_id = ns_id or 0

  vim.api.nvim_buf_add_highlight(self.handle, ns_id, name, line, col_start, col_end)
end
function Buffer:unplace_sign(id)
  vim.cmd("sign unplace " .. id)
end
function Buffer:place_sign(line, name, group, id)
  -- Sign IDs should be unique within a group, however there's no downside as
  -- long as we don't want to uniquely identify the placed sign later. Thus,
  -- we leave the choice to the caller
  local sign_id = id or 1

  -- There's an equivalent function sign_place() which can automatically use
  -- a free ID, but is considerable slower, so we use the command for now
  local cmd = "sign place " .. sign_id .. " line=" .. line .. " name=" .. name
  if group ~= nil then
    cmd = cmd .. " group=" .. group
  end
  cmd = cmd .. " buffer=" .. self.handle

  vim.cmd(cmd)
  return sign_id
end

function Buffer:get_sign_at_line(line, group)
  group = group or "*"
  return vim.fn.sign_getplaced(self.handle, {
    group = group,
    lnum = line,
  })[1]
end

function Buffer:clear_sign_group(group)
  vim.cmd("sign unplace * group=" .. group .. " buffer=" .. self.handle)
end

function Buffer:set_filetype(ft)
  vim.api.nvim_buf_set_option(self.handle, "filetype", ft)
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

---@return Buffer
function Buffer.create(config)
  config = config or {}
  local kind = config.kind or "split"
  local buffer = Buffer:new(api.nvim_create_buf(false, false))
  buffer.kind = kind

  if config.open ~= false then
    buffer:show()
  end

  buffer:set_name(config.name)

  buffer:set_option("bufhidden", config.bufhidden or "wipe")
  buffer:set_option("buftype", config.buftype or "nofile")
  buffer:set_option("swapfile", false)

  if config.filetype then
    buffer:set_filetype(config.filetype)
  end

  if config.mappings then
    for mode, val in pairs(config.mappings) do
      for key, cb in pairs(val) do
        buffer.mmanager.mappings[key] = {
          mode,
          function()
            cb(buffer)
          end,
          mode:find("v") ~= nil,
        }
      end
    end
  end

  if config.initialize then
    config.initialize(buffer)
  end

  if config.render then
    buffer.ui:render(unpack(config.render(buffer)))
  end

  if config.autocmds then
    for event, cb in pairs(config.autocmds) do
      table.insert(__BUFFER_AUTOCMD_STORE, cb)
      local id = #__BUFFER_AUTOCMD_STORE
      buffer:define_autocmd(event, string.format("lua __BUFFER_AUTOCMD_STORE[%d]()", id))
    end
  end

  buffer.mmanager.register()

  if not config.modifiable then
    buffer:set_option("modifiable", false)
    buffer:set_option("modified", false)
  end

  if config.readonly ~= nil and config.readonly then
    buffer:set_option("readonly", true)
  end

  -- This sets fold styling for Neogit windows without overriding user styling
  buffer:call(function()
    local hl = vim.wo.winhl
    if hl ~= "" then
      hl = hl .. ","
    end
    vim.wo.winhl = hl .. "Folded:NeogitFold"
  end)

  return buffer
end

return Buffer
