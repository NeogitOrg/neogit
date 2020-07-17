managers = {}

local function new(id)
  local mappings = {}
  local manager = {
    id = id,
    mappings = mappings,
    add = function(key, f)
      mappings[key] = f
    end
  }

  table.insert(managers, manager)

  return manager
end

local function delete(manager)
end

return {
  new = new,
  delete = delete
}
