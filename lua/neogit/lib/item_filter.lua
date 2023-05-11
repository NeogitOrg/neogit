local Collection = require("neogit.lib.collection")

local ItemFilter = {}

function ItemFilter.new(tbl)
  return setmetatable(tbl, { __index = ItemFilter })
end

function ItemFilter.create(items)
  return ItemFilter.new(Collection.new(items):map(function(item)
    local section, file = item:match("^([^:]+):(.*)$")
    if not section then
      error("Invalid filter item: " .. item, 3)
    end

    return { section = section, file = file }
  end))
end

function ItemFilter:accepts(section, item)
  local function valid_section(f)
    return f.section == "*" or f.section == section
  end

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
