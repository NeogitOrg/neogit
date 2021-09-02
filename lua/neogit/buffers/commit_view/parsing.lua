local M = {}

local util = require 'neogit.lib.util'
local diff_lib = require('neogit.lib.git.diff')

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
    files = {}
  }

  for i=2,#raw-1 do
    local file = {}
    if raw[i] ~= "" then
      file.path, file.changes, file.insertions, file.deletions = raw[i]:match(" (.*)%s+|%s+(%d+) (%+*)(%-*)")
      table.insert(overview.files, file)
    end
  end

  setmetatable(overview, { __index = CommitOverview })

  return overview
end

-- @class CommitInfo
-- @field oid the oid of the commit
-- @field author_name the name of the author
-- @field author_email the email of the author
-- @field author_date when the author commited
-- @field committer_name the name of the committer
-- @field committer_email the email of the committer
-- @field committer_date when the committer commited
-- @field description a list of lines
-- @field diffs a list of diffs
-- @see Diff
local CommitInfo = {}

-- @return the abbreviation of the oid
function CommitInfo:abbrev()
  return self.oid:sub(1, 7)
end

function M.parse_commit_info(raw_info)
  local idx = 0

  local function advance()
    idx = idx + 1
    return raw_info[idx]
  end

  local function peek()
    return raw_info[idx + 1]
  end

  local info = {}
  info.oid = advance():match("commit (%w+)")
  if vim.startswith(peek(), "Merge:") then
    info.merge = advance():match("Merge:%s*(.+) <(.+)>")
  end
  info.author_name, info.author_email = advance():match("Author:%s*(.+) <(.+)>")
  info.author_date = advance():match("AuthorDate:%s*(.+)")
  info.committer_name, info.committer_email = advance():match("Commit:%s*(.+) <(.+)>")
  info.committer_date = advance():match("CommitDate:%s*(.+)")
  info.description = {}
  info.diffs = {}
  
  -- skip empty line
  advance()

  local line = advance()
  while line ~= "" do
    table.insert(info.description, util.trim(line))
    line = advance()
  end

  local raw_diff_info = {}

  local line = advance()
  while line do
    table.insert(raw_diff_info, line)
    line = advance()
    if line == nil or vim.startswith(line, "diff") then
      table.insert(info.diffs, diff_lib.parse(raw_diff_info))
      raw_diff_info = {}
    end
  end

  setmetatable(info, { __index = CommitInfo })

  return info
end

return M
