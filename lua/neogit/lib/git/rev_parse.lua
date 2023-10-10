local M = {}

local cli = require("neogit.lib.git.cli")

---@param oid string
---@return string
---@async
function M.abbreviate_commit(oid)
  assert(oid, "Missing oid")

  if oid == "(initial)" then
    return "(initial)"
  else
    return cli["rev-parse"].short.args(oid).call().stdout[1]
  end
end

return M
