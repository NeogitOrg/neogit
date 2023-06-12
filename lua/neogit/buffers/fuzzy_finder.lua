local Finder = require("neogit.lib.finder")

local function buffer_height(count)
  if count < (vim.fn.winheight(0) / 2) then
    return count + 2
  else
    return 0.5
  end
end

---@class FuzzyFinderBuffer
---@field list table list of items to search
---@field action function action dispatched by line selection
---@field buffer Buffer
---@field open_async function
---@field open function
local M = {}

---Creates a new FuzzyFinderBuffer
---@param list any[]
---@return FuzzyFinderBuffer
function M.new(list)
  local instance = {
    list = list,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open(opts, action)
  opts = opts or {
    allow_multi = false,
    layout_config = { height = buffer_height(#self.list) },
  }

  Finder.create(opts):add_entries(self.list):find(action)
end

---@param opts FinderOpts
---@return any|nil
--- Asynchronously prompt the user for the selection, and return the selected item or nil if aborted.
function M:open_async(opts)
  opts = opts or {
    allow_multi = false,
    layout_config = { height = buffer_height(#self.list) },
  }

  return Finder.create(opts):add_entries(self.list):find_async()
end

function M.test()
  local async = require("plenary.async")
  async.run(function()
    local buffer = M.new { "a", "b", "c" }
    local item = buffer:open_async {}

    print("Selected: " .. vim.inspect(item))
  end)
end

return M
