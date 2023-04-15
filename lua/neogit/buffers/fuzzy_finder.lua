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
---@field open_sync function
---@field open function

---Creates a new FuzzyFinderBuffer
---@param list table
---@param action function|nil Action is not required if calling :open_sync()
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
  opts = opts or {
    allow_multi = false,
    layout_config = { height = buffer_height(#self.list) },
  }

  local select_action = function(prompt_bufnr)
    local selection = {}

    local picker = action_state.get_current_picker(prompt_bufnr)
    if #picker:get_multi_selection() > 0 then
      for _, item in ipairs(picker:get_multi_selection()) do
        table.insert(selection, item[1])
      end
    else
      table.insert(selection, action_state.get_selected_entry()[1])
    end

    if not selection[1] or selection[1] == "" then
      return
    end

    actions.close(prompt_bufnr)

    if opts.allow_multi then
      self.action(selection)
    else
      self.action(selection[1])
    end
  end

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
