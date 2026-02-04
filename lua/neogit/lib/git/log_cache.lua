local git = require("neogit.lib.git")

---@class NeogitLogCache
local M = {}

---@type table<string, CommitLogEntry[]>
local cache = {}

--- Parse a range like "@{upstream}.." or "..origin/main" into from_ref and to_ref
---@param range string
---@return string|nil from_ref
---@return string|nil to_ref
local function parse_range(range)
  local from, to = range:match("^(.*)%.%.(.*)$")
  if not from then
    return nil, nil
  end
  if from == "" then
    return nil, to ~= "" and to or "HEAD"
  elseif to == "" then
    return from, "HEAD"
  else
    return from, to
  end
end

--- Resolve a ref to its OID
---@param ref string
---@return string|nil oid
local function resolve_oid(ref)
  local result = git.cli["rev-parse"].args(ref).call({ hidden = true, ignore_error = true })
  if result:success() and result.stdout[1] then
    return result.stdout[1]
  end
  return nil
end

--- Get cached log results for a range
---@param range string e.g., "@{upstream}.." or "..origin/main"
---@return CommitLogEntry[]|nil
function M.get(range)
  local from_ref, to_ref = parse_range(range)
  if not from_ref and not to_ref then
    return nil
  end

  local from_oid = from_ref and resolve_oid(from_ref)
  local to_oid = resolve_oid(to_ref or "HEAD")

  if not to_oid then
    return nil
  end

  local key = string.format("%s..%s", from_oid or "", to_oid)
  return cache[key]
end

--- Cache log results for a range
---@param range string
---@param commits CommitLogEntry[]
function M.set(range, commits)
  local from_ref, to_ref = parse_range(range)
  if not from_ref and not to_ref then
    return
  end

  local from_oid = from_ref and resolve_oid(from_ref)
  local to_oid = resolve_oid(to_ref or "HEAD")

  if not to_oid then
    return
  end

  local key = string.format("%s..%s", from_oid or "", to_oid)
  cache[key] = commits
end

--- Clear all cached log results
function M.clear()
  cache = {}
end

return M
