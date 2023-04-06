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

---@class FuzzyFinderBuffer
---@field list table list of items to search
---@field action function action dispatched by line selection
---@field buffer Buffer
---@field open function

---Creates a new FuzzyFinderBuffer
---@param list table
---@param action function
---@return FuzzyFinderBuffer
function M.new(list, action)
  local instance = {
    action = action,
    list = list,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open(opts)
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

  opts = opts or { layout_config = { height = buffer_height(#self.list) } }

  Finder.create(opts)
    :add_entries(self.list)
    :add_select_action(select_action)
    :find()
end

-- Opens finder in such a way that selected value can be returned to the main thread
-- without the need to use a callback to process the selection.
function M:open_sync(...)
  local tx, rx = require("plenary.async.control").channel.oneshot()
  local result

  self.action = function(selection)
    result = selection
    tx()
  end

  self:open(...)

  rx()
  return result
end

return M
