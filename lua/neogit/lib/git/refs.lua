local cli = require("neogit.lib.git.cli")
local record = require("neogit.lib.record")
local repo = require("neogit.lib.git.repository")

local M = {}

--- Lists revisions
---@return table
function M.list()
  local revisions = cli["for-each-ref"].format('"%(refname:short)"').call().stdout
  for i, str in ipairs(revisions) do
    revisions[i] = string.sub(str, 2, -2)
  end
  return revisions
end

local record_template = record.encode {
  head = "%(HEAD)",
  oid = "%(objectname)",
  ref = "%(refname)",
  name = "%(refname:short)",
  upstream_status = "%(upstream:trackshort)",
  upstream_name = "%(upstream:short)",
  subject = "%(subject)",
}

function M.list_parsed()
  local refs = cli["for-each-ref"].format(record_template).call_sync():trim().stdout
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
    if repo:git_path(head):exists() then
      table.insert(present, head)
    end
  end

  return present
end

return M
