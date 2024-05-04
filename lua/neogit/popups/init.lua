---@class Popups
---@field open fun(name: string, f: nil|fun(create: fun(...): any)): fun(): any
---@field mapping_for fun(name: string):string|string[]
local M = {}

---Creates a curried function which will open the popup with the given name when called
---@param name string
---@param f nil|fun(create: fun(...)): any
---@return fun(): any
function M.open(name, f)
  f = f or function(c)
    c()
  end

  return function()
    local ok, value = pcall(require, "neogit.popups." .. name)
    if ok then
      assert(value, "popup is not nil")
      assert(value.create, "popup has create function")

      f(value.create)
    else
      local notification = require("neogit.lib.notification")
      notification.error(string.format("Failed to load popup: %q\n%s", name, value))
    end
  end
end

---Returns the keymapping for a popup
---@param name string
---@return string|string[]
function M.mapping_for(name)
  local mappings = require("neogit.config").get_reversed_popup_maps()

  if mappings[name] then
    return mappings[name]
  else
    return {}
  end
end

return M
