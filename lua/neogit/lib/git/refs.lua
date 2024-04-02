local git = require("neogit.lib.git")
local config = require("neogit.config")
local record = require("neogit.lib.record")
local util = require("neogit.lib.util")

local M = {}

---@param namespaces? string[]
---@param format? string format string passed to `git for-each-ref`
---@param sortby? string sort by string passed to `git for-each-ref`
---@return table
function M.list(namespaces, format, sortby)
  return util.filter_map(
    git.cli["for-each-ref"]
      .format(format or "%(refname)")
      .sort(sortby or config.values.sort_branches)
      .call({ hidden = true }).stdout,
    function(revision)
      for _, namespace in ipairs(namespaces or { "refs/heads", "refs/remotes", "refs/tags" }) do
        if revision:match("^" .. namespace) then
          local name, _ = revision:gsub("^" .. namespace .. "/", "")
          return name
        end
      end
    end
  )
end

---@return string[]
function M.list_tags()
  return M.list { "refs/tags" }
end

---@return string[]
function M.list_branches()
  return util.merge(M.list_local_branches(), M.list_remote_branches())
end

---@return string[]
function M.list_local_branches()
  return M.list { "refs/heads" }
end

---@param remote? string Filter branches by remote
---@return string[]
function M.list_remote_branches(remote)
  local remote_branches = M.list { "refs/remotes" }

  if remote then
    return vim.tbl_filter(function(ref)
      return ref:match("^" .. remote .. "/")
    end, remote_branches)
  else
    return remote_branches
  end
end

local record_template = record.encode({
  head = "%(HEAD)",
  oid = "%(objectname)",
  ref = "%(refname)",
  name = "%(refname:short)",
  upstream_status = "%(upstream:trackshort)",
  upstream_name = "%(upstream:short)",
  subject = "%(subject)",
}, "ref")

function M.list_parsed()
  local refs = git.cli["for-each-ref"].format(record_template).show_popup(false).call({ hidden = true }).stdout
  local result = record.decode(refs)

  local output = {
    local_branch = {},
    remote_branch = {},
    tag = {},
  }

  for _, ref in ipairs(result) do
    ref.head = ref.head == "*"

    if ref.ref:match("^refs/heads/") then
      ref.type = "local_branch"
      table.insert(output.local_branch, ref)
    elseif ref.ref:match("^refs/remotes/") then
      local remote, branch = ref.ref:match("^refs/remotes/([^/]*)/(.*)$")
      if not output.remote_branch[remote] then
        output.remote_branch[remote] = {}
      end

      ref.type = "remote_branch"
      ref.name = branch
      table.insert(output.remote_branch[remote], ref)
    elseif ref.ref:match("^refs/tags/") then
      ref.type = "tag"
      table.insert(output.tag, ref)
    end
  end

  return output
end

-- TODO: Use in more places
--- Determines what HEAD's exist in repo, and enumerates them
function M.heads()
  local heads = { "HEAD", "ORIG_HEAD", "FETCH_HEAD", "MERGE_HEAD", "CHERRY_PICK_HEAD" }
  local present = {}
  for _, head in ipairs(heads) do
    if git.repo:git_path(head):exists() then
      table.insert(present, head)
    end
  end

  return present
end

return M
