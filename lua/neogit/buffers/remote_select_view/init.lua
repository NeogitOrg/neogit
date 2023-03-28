local Finder = require("neogit.lib.finder")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

---@class RemoteSelectViewBuffer
---@field remotes table the remotes list
---@field action function action dispatched by line selection
---@see Finder
--
---Creates a new RemoteSelectViewBuffer
---@param remotes table
---@param action function
---@return RemoteSelectViewBuffer
function M.new(remotes, action)
  local instance = {
    action = action,
    remotes = remotes,
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
    if self.action and selection[1] ~= "" then
      self.action(selection[1])
    end
  end

  Finder.create():add_entries(self.remotes):add_select_action(select_action):find()
end

return M
