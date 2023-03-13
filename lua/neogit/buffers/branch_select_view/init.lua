local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.branch_select_view.ui")

local M = {}

-- @class BranchSelectViewBuffer
-- @field branches the branches list
-- @field action action dispatched by line selection
-- @field buffer Buffer
-- @see Buffer
--
--- Creates a new BranchSelectViewBuffer
-- @param branches
-- @param action
-- @return BranchSelectViewBuffer
function M.new(branches, action)
  local instance = {
    action = action,
    branches = branches,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end

function M:open()
  self.buffer = Buffer.create {
    name = "NeogitBranchSelectView",
    filetype = "NeogitBranchSelectView",
    kind = "split",
    mappings = {
      n = {
        ["<enter>"] = function(buffer)
          local current_line = buffer:get_current_line()
          local branch_name = current_line[1]
          if self.action then
            self.action(branch_name)
          end
          self:close()
        end,
      },
    },
    render = function()
      return ui.View(self.branches)
    end,
  }
end

return M
