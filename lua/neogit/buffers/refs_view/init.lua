local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.refs_view.ui")
local config = require("neogit.config")
-- local popups = require("neogit.popups")

--- @class RefsViewBuffer
--- @field is_open boolean whether the buffer is currently shown
--- @field buffer Buffer
--- @field open fun()
--- @field close fun()
--- @see RefsInfo
--- @see Buffer
--- @see Ui
local M = {
  instance = nil,
}

--- Creates a new RefsViewBuffer
--- @return RefsViewBuffer
function M.new(refs)
  local instance = {
    refs = refs,
    is_open = false,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })
  return instance
end

--- Closes the RefsViewBuffer
function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end

--- Opens the RefsViewBuffer
--- If already open will close the buffer
function M:open()
  if M.instance and M.instance.is_open then
    M.instance:close()
  end

  M.instance = self

  if self.is_open then
    return
  end

  self.hovered_component = nil
  self.is_open = true

  self.buffer = Buffer.create {
    name = "NeogitRefsView",
    filetype = "NeogitRefsView",
    kind = "auto",
    context_highlight = false,
    autocmds = {
      ["BufUnload"] = function()
        M.instance.is_open = false
      end,
    },
    mappings = {
      n = {},
    },
    render = function()
      return ui.RefsView(self.refs)
    end,
    after = function()
      vim.cmd([[setlocal nowrap nospell]])
    end,
  }
end

return M
