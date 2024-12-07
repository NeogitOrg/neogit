local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")

---@class ProcessBuffer
---@field content string[]
---@field truncated boolean
---@field buffer Buffer
---@field process Process
local M = {}
M.__index = M

---@param process Process
---@param mask_fn fun(string):string
---@return ProcessBuffer
function M:new(process, mask_fn)
  local instance = {
    content = { string.format("> %s\r\n", mask_fn(table.concat(process.cmd, " "))) },
    process = process,
    buffer = nil,
    truncated = false,
  }

  setmetatable(instance, self)
  return instance
end

function M:hide()
  if self.buffer then
    self.buffer:hide()
  end
end

function M:close()
  if self.buffer then
    self.buffer:close_terminal_channel()
    self.buffer:close()
    self.buffer = nil
  end
end

function M:focus()
  assert(self.buffer, "Create a buffer first")
  self.buffer:focus()
end

function M:show()
  if not self.buffer then
    self:open()
  end

  self.buffer:show()
  self:flush_content()
end

function M:is_visible()
  return self.buffer and self.buffer:is_valid() and self.buffer:is_visible()
end

---@param data string
function M:append(data)
  assert(data, "no data to append")

  if self:is_visible() then
    self:flush_content()
    self.buffer:chan_send(data .. "\r\n")
  else
    table.insert(self.content, data)
  end
end

---@param data string
function M:append_partial(data)
  assert(data, "no data to append")

  if self:is_visible() then
    self.buffer:chan_send(data)
  end
end

function M:flush_content()
  if #self.content > 0 then
    self.buffer:chan_send(table.concat(self.content, "\r\n") .. "\r\n")
    self.content = {}
  end
end

local function close(self)
  return function()
    self.process:stop()
    self:close()
  end
end

---@return ProcessBuffer
function M:open()
  if self.buffer then
    return self
  end

  local status_maps = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitConsole",
    filetype = "NeogitConsole",
    bufhidden = "hide",
    open = false,
    buftype = false,
    kind = config.values.preview_buffer.kind,
    after = function(buffer)
      buffer:open_terminal_channel()
    end,
    mappings = {
      n = {
        ["<c-c>"] = function()
          pcall(self.process.stop, self.process)
        end,
        [status_maps["Close"]] = close(self),
        ["<esc>"] = close(self),
      },
    },
  }

  return self
end

return M
