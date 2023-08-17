local M = {}

local cli = require("neogit.lib.git.cli")

---@param oid string
---@return string
---@async
function M.abbreviate_commit(oid)
  assert(oid, "Missing oid")
  local abbrev= cli["rev-parse"].short.args(oid).call().stdout[1]
  assert(abbrev and abbrev ~= "", "Failed to abbreviate commit")
  return abbrev
end

return M
