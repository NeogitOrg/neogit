local Buffer = require 'neogit.lib.buffer'
local ui = require 'neogit.buffers.status.ui'

local M = {}

-- @class StatusBuffer
-- @field is_open whether the buffer is currently visible
-- @field buffer buffer instance
-- @field state StatusState
-- @see Buffer
-- @see StatusState

function M.new(state)
  local x = {
    is_open = false,
    state = state,
    buffer = nil
  }
  setmetatable(x, { __index = M })
  return x 
end

function M:open(kind)
  kind = kind or "tab"

  self.buffer = Buffer.create {
    name = "NeogitStatusNew",
    filetype = "NeogitStatusNew",
    kind = kind,
    initialize = function()
      self.prev_autochdir = vim.o.autochdir

      vim.o.autochdir = false
    end,
    render = function()
      return ui.Status(self.state)
    end
  }
end

return M
