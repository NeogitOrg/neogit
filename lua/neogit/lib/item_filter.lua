local Collection = require("neogit.lib.collection")

---@class ItemFilter
---@field new fun(table): ItemFilter
---@field create fun(table): ItemFilter
---@field accepts fun(self, string, string): boolean
local ItemFilter = {}
ItemFilter.__index = ItemFilter

---@return ItemFilter
function ItemFilter.new(instance)
  return setmetatable(instance, ItemFilter)
end

---@param items string[]
---@return ItemFilter
function ItemFilter.create(items)
  return ItemFilter.new(Collection.new(items):map(function(item)
    local section, file = item:match("^([^:]+):(.*)$")
    assert(section, "Invalid filter item: " .. item)

    return { section = section, file = file }
  end))
end

---@param section string
---@param item string
---@return boolean
function ItemFilter:accepts(section, item)
  ---@return boolean
  local function valid_section(f)
    return f.section == "*" or f.section == section
  end

  ---@return boolean
  local function valid_file(f)
    return f.file == "*" or f.file == item
  end

  for _, f in ipairs(self) do
    if valid_section(f) and valid_file(f) then
      return true
    end
  end

  return false
end

return ItemFilter
