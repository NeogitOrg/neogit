local M = {}

local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

---@param oid string
---@return string
---@async
M.abbreviate_commit = util.memoize(function(oid)
  assert(oid, "Missing oid")

  if oid == "(initial)" then
    return "(initial)"
  else
    return cli["rev-parse"].short.args(oid).call({ hidden = true, ignore_error = true }).stdout[1]
  end
end, { timeout = math.huge })

---@param rev string
---@return string
---@async
function M.oid(rev)
  return cli["rev-parse"].args(rev).call_sync({ hidden = true, ignore_error = true }).stdout[1]
end

return M
