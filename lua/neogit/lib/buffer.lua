local api = vim.api
local fn = vim.fn
package.loaded["neogit.buffer"] = nil

__BUFFER_AUTOCMD_STORE = {}

local mappings_manager = require("neogit.lib.mappings_manager")
local Ui = require("neogit.lib.ui")

---@class Buffer
---@field handle number
---@field mmanager MappingsManager
---@field ui Ui
---@field kind string
---@field disable_line_numbers boolean
---@field disable_relative_line_numbers boolean
local Buffer = {
  kind = "split",
  disable_line_numbers = true,
  disable_relative_line_numbers = true,
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
    namespace = api.nvim_create_namespace("neogit-buffer-" .. handle),
    line_buffer = {},
    hl_buffer = {},
    sign_buffer = {},
    ext_buffer = {},
  }

  this.ui = Ui.new(this)

  setmetatable(this, self)

  return this
end

---@return number|nil
function Buffer:focus()
  local windows = fn.win_findbuf(self.handle)

  if #windows == 0 then
    return nil
  end

  fn.win_gotoid(windows[1])
  return windows[1]
end

function Buffer:is_focused()
  return api.nvim_win_get_buf(0) == self.handle
end

function Buffer:get_changedtick()
  return api.nvim_buf_get_changedtick(self.handle)
end

function Buffer:lock()
  self:set_option("readonly", true)
  self:set_option("modifiable", false)
end

function Buffer:define_autocmd(events, script)
  vim.cmd(string.format("au %s <buffer=%d> %s", events, self.handle, script))
end

function Buffer:clear()
  api.nvim_buf_set_lines(self.handle, 0, -1, false, {})
end

function Buffer:write()
  self:call(function()
    vim.cmd("silent w!")
  end)
end

function Buffer:get_lines(first, last, strict)
  return api.nvim_buf_get_lines(self.handle, first, last, strict or false)
end

function Buffer:get_line(line)
  return fn.getbufline(self.handle, line)
end

function Buffer:get_current_line()
  return self:get_line(fn.getpos(".")[2])
end

function Buffer:set_lines(first, last, strict, lines)
  api.nvim_buf_set_lines(self.handle, first, last, strict, lines)
end

function Buffer:insert_line(line)
  local line_nr = fn.line(".") - 1
  api.nvim_buf_set_lines(self.handle, line_nr, line_nr, false, { line })
end

function Buffer:buffered_set_line(line)
  table.insert(self.line_buffer, line)
end

function Buffer:buffered_add_highlight(...)
  table.insert(self.hl_buffer, { ... })
end

function Buffer:buffered_place_sign(...)
  table.insert(self.sign_buffer, { ... })
end

function Buffer:buffered_set_extmark(...)
  table.insert(self.ext_buffer, { ... })
end

function Buffer:resize(length)
  api.nvim_buf_set_lines(self.handle, length, -1, false, {})
end

function Buffer:flush_buffers()
  self:clear_namespace(self.namespace)

  api.nvim_buf_set_lines(self.handle, 0, -1, false, self.line_buffer)
  self.line_buffer = {}

  for _, sign in ipairs(self.sign_buffer) do
    self:place_sign(unpack(sign))
  end
  self.sign_buffer = {}

  for _, hl in ipairs(self.hl_buffer) do
    self:add_highlight(unpack(hl))
  end
  self.hl_buffer = {}

  for _, ext in ipairs(self.ext_buffer) do
    self:set_extmark(unpack(ext))
  end
  self.ext_buffer = {}
end

function Buffer:set_text(first_line, last_line, first_col, last_col, lines)
  api.nvim_buf_set_text(self.handle, first_line, first_col, last_line, last_col, lines)
end

function Buffer:move_cursor(line)
  api.nvim_win_set_cursor(0, { line, 0 })
end

function Buffer:close(force)
  if force == nil then
    force = false
  end

  if self.kind == "replace" then
    api.nvim_buf_delete(self.handle, { force = force })
    return
  end

  if api.nvim_buf_is_valid(self.handle) then
    local winnr = fn.bufwinnr(self.handle)
    if winnr ~= -1 then
      local winid = fn.win_getid(winnr)
      if not pcall(api.nvim_win_close, winid, force) then
        vim.cmd("b#")
      end
    else
      api.nvim_buf_delete(self.handle, { force = force })
    end
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
  local windows = fn.win_findbuf(self.handle)

  -- Already visible
  if #windows > 0 then
    return windows[1]
  end

  if self.kind == "auto" then
    if vim.o.columns / 2 < 80 then
      self.kind = "split"
    else
      self.kind = "vsplit"
    end
  end

  local win
  local kind = self.kind

  if kind == "replace" then
    self.old_buf = api.nvim_get_current_buf()
    api.nvim_set_current_buf(self.handle)
    win = api.nvim_get_current_win()
  elseif kind == "tab" then
    vim.cmd("tab split")
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

    local content_window = api.nvim_open_win(self.handle, true, {
      relative = "editor",
      width = width,
      height = height,
      col = col,
      row = row,
      style = "minimal",
      focusable = false,
      border = "single",
    })

    api.nvim_win_set_cursor(content_window, { 1, 0 })
    win = content_window
  end

  if self.disable_line_numbers then
    vim.cmd("setlocal nonu")
  end

  if self.disable_relative_line_numbers then
    vim.cmd("setlocal nornu")
  end

  return win
end

function Buffer:is_valid()
  return api.nvim_buf_is_valid(self.handle)
end

function Buffer:put(lines, after, follow)
  self:focus()
  api.nvim_put(lines, "l", after, follow)
end

function Buffer:create_fold(first, last)
  vim.cmd(string.format(self.handle .. "bufdo %d,%dfold", first, last))
end

function Buffer:unlock()
  self:set_option("readonly", false)
  self:set_option("modifiable", true)
end

function Buffer:get_option(name)
  return api.nvim_buf_get_option(self.handle, name)
end

function Buffer:set_option(name, value)
  api.nvim_buf_set_option(self.handle, name, value)
end

function Buffer:set_name(name)
  api.nvim_buf_set_name(self.handle, name)
end

function Buffer:set_foldlevel(level)
  vim.cmd("setlocal foldlevel=" .. level)
end

function Buffer:replace_content_with(lines)
  api.nvim_buf_set_lines(self.handle, 0, -1, false, lines)
end

function Buffer:open_fold(line, reset_pos)
  local pos
  if reset_pos == true then
    pos = fn.getpos()
  end

  fn.setpos(".", { self.handle, line, 0, 0 })
  vim.cmd("normal zo")

  if reset_pos == true then
    fn.setpos(".", pos)
  end
end

function Buffer:add_highlight(line, col_start, col_end, name, ns_id)
  local ns_id = ns_id or self.namespace

  api.nvim_buf_add_highlight(self.handle, ns_id, name, line, col_start, col_end)
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
  local cmd = {
    string.format("sign place %d", sign_id),
    string.format("line=%d", line),
    string.format("name=%s", name),
  }

  if group then
    table.insert(cmd, string.format("group=%s", group))
  end

  table.insert(cmd, string.format("buffer=%d", self.handle))

  vim.cmd(table.concat(cmd, " "))
  return sign_id
end

function Buffer:get_sign_at_line(line, group)
  group = group or "*"
  return fn.sign_getplaced(self.handle, {
    group = group,
    lnum = line,
  })[1]
end

function Buffer:clear_sign_group(group)
  vim.cmd(string.format("sign unplace * group=%s buffer=%s", group, self.handle))
end

function Buffer:clear_namespace(namespace)
  api.nvim_buf_clear_namespace(self.handle, namespace, 0, -1)
end

function Buffer:create_namespace(name)
  return api.nvim_create_namespace(name)
end

function Buffer:set_filetype(ft)
  api.nvim_buf_set_option(self.handle, "filetype", ft)
end

function Buffer:call(f)
  api.nvim_buf_call(self.handle, f)
end

function Buffer:exists()
  return fn.bufnr(self.handle) ~= -1
end

function Buffer:set_extmark(...)
  return api.nvim_buf_set_extmark(self.handle, ...)
end

function Buffer:get_extmark(ns, id)
  return api.nvim_buf_get_extmark_by_id(self.handle, ns, id, { details = true })
end

function Buffer:del_extmark(ns, id)
  return api.nvim_buf_del_extmark(self.handle, ns, id)
end

function Buffer:set_decorations(namespace, opts)
  return api.nvim_set_decoration_provider(namespace, opts)
end

local uv_utils = require("neogit.lib.uv")

---@class BufferConfig
---@field name string
---@field load boolean
---@field bufhidden string|nil
---@field buftype string|nil
---@field swapfile boolean
---@field filetype string|nil
---@field disable_line_numbers boolean|nil
---@field disable_relative_line_numbers boolean|nil
---@return Buffer
function Buffer.create(config)
  config = config or {}
  local kind = config.kind or "split"
  local disable_line_numbers = (config.disable_line_numbers == nil) and true or config.disable_line_numbers
  local disable_relative_line_numbers = (config.disable_relative_line_numbers == nil) and true
    or config.disable_relative_line_numbers
  --- This reuses a buffer with the same name
  local buffer = fn.bufnr(config.name)

  if buffer == -1 then
    buffer = api.nvim_create_buf(false, false)
    api.nvim_buf_set_name(buffer, config.name)
  end

  if config.load then
    local content = uv_utils.read_file_sync(config.name)
    api.nvim_buf_set_lines(buffer, 0, -1, false, content)
    api.nvim_buf_call(buffer, function()
      vim.cmd("silent w!")
    end)
  end

  local buffer = Buffer:new(buffer)
  buffer.kind = kind
  buffer.disable_line_numbers = disable_line_numbers
  buffer.disable_relative_line_numbers = disable_relative_line_numbers

  local win
  if config.open ~= false then
    win = buffer:show()
  end

  buffer:set_option("bufhidden", config.bufhidden or "wipe")
  buffer:set_option("buftype", config.buftype or "nofile")
  buffer:set_option("swapfile", false)

  if config.filetype then
    buffer:set_filetype(config.filetype)
  end

  if config.mappings then
    for mode, val in pairs(config.mappings) do
      for key, cb in pairs(val) do
        if type(key) == "string" then
          buffer.mmanager.mappings[mode][key] = function()
            cb(buffer)
          end
        elseif type(key) == "table" then
          for _, k in ipairs(key) do
            buffer.mmanager.mappings[mode][k] = function()
              cb(buffer)
            end
          end
        end
      end
    end
  end

  if config.initialize then
    config.initialize(buffer, win)
  end

  if config.render then
    buffer.ui:render(unpack(config.render(buffer)))
  end

  local neogit_augroup = require("neogit").autocmd_group
  for event, callback in pairs(config.autocmds or {}) do
    api.nvim_create_autocmd(event, { callback = callback, buffer = buffer.handle, group = neogit_augroup })
  end

  buffer.mmanager.register()

  if not config.modifiable then
    buffer:set_option("modifiable", false)
    buffer:set_option("modified", false)
  end

  if config.readonly == true then
    buffer:set_option("readonly", true)
  end

  if config.after then
    buffer:call(function()
      config.after(buffer, win)
    end)
  end

  buffer:call(function()
    -- Set fold styling for Neogit windows while preserving user styling
    vim.opt_local.winhl:append("Folded:NeogitFold")

    -- Set signcolumn unless disabled by user settings
    if not config.disable_signs then
      vim.opt_local.signcolumn = "auto"
    end
  end)

  if config.context_highlight then
    buffer:call(function()
      local decor_ns = api.nvim_create_namespace("NeogitBufferViewDecor" .. config.name)
      local context_ns = api.nvim_create_namespace("NeogitBufferitViewContext" .. config.name)

      local function on_start()
        return buffer:exists() and buffer:is_focused()
      end

      local function on_win()
        buffer:clear_namespace(context_ns)

        -- TODO: this is WAY to slow to be called so frequently, especially in a large buffer
        local stack = buffer.ui:get_component_stack_under_cursor()
        if not stack then
          return
        end

        local hovered_component = stack[2] or stack[1]
        local first, last = hovered_component:row_range_abs()
        local top_level = hovered_component.parent and not hovered_component.parent.parent

        for line = fn.line("w0"), fn.line("w$") do
          if first and last and line >= first and line <= last and not top_level then
            local sign = buffer.ui:get_component_stack_on_line(line)[1].options.sign

            buffer:set_extmark(
              context_ns,
              line - 1,
              0,
              { line_hl_group = (sign or "NeogitDiffContext") .. "Highlight", priority = 10 }
            )
          end
        end
      end

      buffer:set_decorations(decor_ns, { on_start = on_start, on_win = on_win })
    end)
  end

  return buffer
end

return Buffer
