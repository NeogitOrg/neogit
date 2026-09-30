local M = {}

local config = require("neogit.config")

---@param name NeogitHook
---@param data table?
function M.run(name, data)
  assert(name, "hook must have name")

  if config.values.hooks[name] then
    config.values.hooks[name](data)
  end
end

return M
