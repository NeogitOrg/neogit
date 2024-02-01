local cli = require("neogit.lib.git.cli")
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
