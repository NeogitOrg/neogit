local Finder = require("neogit.lib.finder")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

local function buffer_height(count)
  if count < (vim.fn.winheight(0) / 2) then
    return count
  else
    return 0.5
  end
end

---@class FileSelectViewBuffer
---@field files the branches list
---@field action action dispatched by line selection
--
--- Creates a new FileSelectViewBuffer
---@param files
---@param action
---@return FileSelectViewBuffer
function M.new(files, action)
  local instance = {
    action = action,
    files = files,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  local select_action = function(prompt_bufnr)
    actions.close(prompt_bufnr)
    local filepath = action_state.get_selected_entry()[1]
    if self.action then
      self.action(filepath)
    end
  end

  Finder.create({ layout_config = { height = buffer_height(#self.files) } })
    :add_entries(self.files)
    :add_select_action(select_action)
    :find()
end

return M
