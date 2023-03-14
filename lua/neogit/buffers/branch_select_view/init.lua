local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
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
  if not config.values.integrations.telescope then
    self.buffer = Buffer.create {
      name = "NeogitBranchSelectView",
      filetype = "NeogitBranchSelectView",
      kind = "split",
      mappings = {
        n = {
          ["q"] = function()
            self:close()
          end,
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
  else
    local Finder = require("neogit.lib.finder")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local select_action = function(prompt_bufnr)
      actions.close(prompt_bufnr)
      local branch_name = action_state.get_selected_entry()[1]
      if self.action then
        self.action(branch_name)
      end
    end

    Finder.create():add_entries(self.branches):add_select_action(select_action):find()
  end
end

return M
