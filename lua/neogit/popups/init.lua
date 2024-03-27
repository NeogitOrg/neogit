local M = {}

---@param name string
---@param f nil|fun(create: fun(...)): any
--- Creates a curried function which will open the popup with the given name when called
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

---@param name string
---@return string|string[]
---Returns the keymapping for a popup
function M.mapping_for(name)
  local mappings = require("neogit.config").get_reversed_popup_maps()

  if mappings[name] then
    return mappings[name]
  else
    return {}
  end
end

return M
