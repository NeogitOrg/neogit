local Buffer = require("neogit.lib.buffer")

local M = {}

function M.new()
  local instance = {
    is_open = false,
    buffer = nil
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  if self.is_open then
    return
  end

  self.is_open = true
  self.buffer = Buffer.create {
    name = "NeogitCommitView",
    filetype = "NeogitCommitView",
    mappings = {

    },
    initialize = function(buffer)
      buffer:set_lines(0, -1, false, { "Hello World" })
    end
  }
end

M.new():open()

return M
