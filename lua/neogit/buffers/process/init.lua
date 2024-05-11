local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local status_maps = require("neogit.config").get_reversed_status_maps()

---@class ProcessBuffer
---@field buffer Buffer
---@field open fun(self)
---@field hide fun(self)
---@field close fun(self)
---@field focus fun(self)
---@field show fun(self)
---@field is_visible fun(self): boolean
---@field append fun(self, data: string)
---@field new fun(self): ProcessBuffer
---@see Buffer
---@see Ui
local M = {}
M.__index = M

---@return ProcessBuffer
---@param process Process
function M:new(process)
  local instance = {
    content = string.format("> %s\r\n", table.concat(process.cmd, " ")),
    process = process,
    buffer = nil,
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

  self.buffer:chan_send(self.content)
  self.buffer:show()
  self.buffer:call(vim.cmd.normal, "G")
end

function M:is_visible()
  return self.buffer and self.buffer:is_visible()
end

function M:append(data)
  vim.schedule(function()
    self.content = table.concat({ self.content, data }, "\r\n")
  end)
end

---@return ProcessBuffer
function M:open()
  if self.buffer then
    return self
  end

  self.buffer = Buffer.create {
    name = "NeogitConsole",
    filetype = "NeogitConsole",
    bufhidden = "hide",
    open = false,
    buftype = false,
    kind = config.values.preview_buffer.kind,
    on_detach = function()
      self.buffer = nil
    end,
    autocmds = {
      ["WinLeave"] = function()
        pcall(self.close, self)
      end,
    },
    mappings = {
      n = {
        [status_maps["Close"]] = function()
          self:hide()
        end,
        ["<esc>"] = function()
          self:hide()
        end,
      },
    },
  }

  return self
end

return M
