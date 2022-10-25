local M = {}

local util = require("neogit.lib.util")

-- @class CommitOverviewFile
-- @field path the path to the file relative to the git root
-- @field changes how many changes were made to the file
-- @field insertions insertion count visualized as list of `+`
-- @field deletions deletion count visualized as list of `-`

-- @class CommitOverview
-- @field summary a short summary about what happened
-- @field files a list of CommitOverviewFile
-- @see CommitOverviewFile
local CommitOverview = {}

function M.parse_commit_overview(raw)
  local overview = {
    summary = util.trim(raw[#raw]),
    files = {},
  }

  for i = 2, #raw - 1 do
    local file = {}
    if raw[i] ~= "" then
      file.path, file.changes, file.insertions, file.deletions = raw[i]:match(" (.*)%s+|%s+(%d+) ?(%+*)(%-*)")
      table.insert(overview.files, file)
    end
  end

  setmetatable(overview, { __index = CommitOverview })

  return overview
end

---@return string the abbreviation of the oid
---@param commit CommitLogEntry
function M.abbrev(commit)
  return commit.oid:sub(1, 7)
end

return M
