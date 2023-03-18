local Finder = require("neogit.lib.finder")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

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
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  local select_action = function(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if not selection then
      return
    end

    actions.close(prompt_bufnr)
    if self.action then
      self.action(selection[1])
    end
  end

  Finder.create():add_entries(self.branches):add_select_action(select_action):find()
end

return M
