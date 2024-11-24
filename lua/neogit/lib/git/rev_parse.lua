local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

---@class NeogitGitRevParse
local M = {}

---@param oid string
---@return string
---@async
M.abbreviate_commit = util.memoize(function(oid)
  assert(oid, "Missing oid")

  if oid == "(initial)" then
    return "(initial)"
  else
    return git.cli["rev-parse"].short.args(oid).call({ hidden = true, ignore_error = true }).stdout[1]
  end
end, { timeout = math.huge })

---@param rev string
---@return string
---@async
function M.oid(rev)
  return git.cli["rev-parse"].args(rev).call({ hidden = true, ignore_error = true }).stdout[1]
end

---@param rev string
---@return string
---@async
function M.verify(rev)
  return git.cli["rev-parse"].verify.abbrev_ref(rev).call({ hidden = true, ignore_error = true }).stdout[1]
end

---@param rev string
---@return string
function M.full_name(rev)
  return git.cli["rev-parse"].verify.symbolic_full_name
    .args(rev)
    .call({ hidden = true, ignore_error = true }).stdout[1]
end

return M
