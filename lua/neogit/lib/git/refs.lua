local git = require("neogit.lib.git")
local config = require("neogit.config")
local record = require("neogit.lib.record")
local util = require("neogit.lib.util")

---@class NeogitGitRefs
local M = {}

---@return fun(format?: string, sortby?: string, filter?: table): string[]
local refs = util.memoize(function(format, sortby, filter)
  return git.cli["for-each-ref"]
    .format(format or "%(refname)")
    .sort(sortby or config.values.sort_branches)
    .arg_list(filter or {})
    .call({ hidden = true }).stdout
end)

---@return string[]
function M.list(namespaces, format, sortby)
  local filter = util.map(namespaces or {}, function(namespace)
    return namespace:sub(2, -1)
  end)

  return util.map(refs(format, sortby, filter), function(revision)
    local name, _ = revision:gsub("^refs/[^/]*/", "")
    return name
  end)
end

---@return string[]
function M.list_tags()
  return M.list { "^refs/tags/" }
end

---@return string[]
function M.list_branches()
  return util.merge(M.list_local_branches(), M.list_remote_branches())
end

---@return string[]
function M.list_local_branches()
  return M.list { "^refs/heads/" }
end

---@param remote? string Filter branches by remote
---@return string[]
function M.list_remote_branches(remote)
  local remote_branches = M.list { "^refs/remotes/" }

  if remote then
    return vim.tbl_filter(function(ref)
      return ref:match("^" .. remote .. "/")
    end, remote_branches)
  else
    return remote_branches
  end
end

local RECORD_TEMPLATE = record.encode({
  head = "%(HEAD)",
  oid = "%(objectname)",
  ref = "%(refname)",
  name = "%(refname:short)",
  upstream_status = "%(upstream:trackshort)",
  upstream_name = "%(upstream:short)",
  subject = "%(subject)",
}, "ref")

---@class ParsedRef
---@field type string
---@field name string
---@field unambiguous_name string
---@field remote string|nil

local insert = table.insert
local format = string.format
local match = string.match
local substring = string.sub

local LOCAL_BRANCH = "local_branch"
local REMOTE_BRANCH = "remote_branch"
local TAG = "tag"
local TAG_TEMPLATE = "tags/%s"
local BRANCH_TEMPLATE = "%s/%s"
local REMOTE_BRANCH_PATTERN = "^refs/remotes/([^/]*)/(.*)$"
local HEAD = "*"
local head = "h"
local remote = "r"
local tag = "t"

function M.list_parsed()
  local result = record.decode(refs(RECORD_TEMPLATE))

  local output = {
    local_branch = {},
    remote_branch = {},
    tag = {},
  }

  for _, ref in ipairs(result) do
    ref.head = ref.head == HEAD

    local ref_type = substring(ref.ref, 6, 6)
    if ref_type == head then
      ref.type = LOCAL_BRANCH
      ref.unambiguous_name = ref.name
      insert(output.local_branch, ref)
    elseif ref_type == remote then
      local remote, branch = match(ref.ref, REMOTE_BRANCH_PATTERN)
      if not output.remote_branch[remote] then
        output.remote_branch[remote] = {}
      end

      ref.type = REMOTE_BRANCH
      ref.name = branch
      ref.unambiguous_name = format(BRANCH_TEMPLATE, remote, branch)
      ref.remote = remote
      insert(output.remote_branch[remote], ref)
    elseif ref_type == tag then
      ref.type = TAG
      ref.unambiguous_name = format(TAG_TEMPLATE, ref.name)
      insert(output.tag, ref)
    end
  end

  return output
end

-- TODO: Use in more places
--- Determines what HEAD's exist in repo, and enumerates them
M.heads = util.memoize(function()
  local heads = { "HEAD", "ORIG_HEAD", "FETCH_HEAD", "MERGE_HEAD", "CHERRY_PICK_HEAD" }
  local present = {}
  for _, head in ipairs(heads) do
    if git.repo:worktree_git_path(head):exists() then
      table.insert(present, head)
    end
  end

  return present
end)

return M
