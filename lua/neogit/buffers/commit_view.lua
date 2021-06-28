local Buffer = require("neogit.lib.buffer")
local cli = require 'neogit.lib.git.cli'
local parse_diff = require('neogit.lib.git.diff').parse

local M = {}

-- @class CommitInfo
-- @field oid the oid of the commit
-- @field author_name the name of the author
-- @field author_email the email of the author
-- @field author_date when the author commited
-- @field committer_name the name of the committer
-- @field committer_email the email of the committer
-- @field committer_date when the committer commited
-- @field description a list of lines
-- @field diff the diff of the commit

local function parse_commit_info(raw_info)
  --  , (%W+/%W+), %W+%)
  local idx = 0

  local function advance()
    idx = idx + 1
    return raw_info[idx]
  end

  local info = {}
  info.oid = advance():match("commit (%w+)")
  info.author_name, info.author_email = advance():match("Author:%s*(%w+) <(%w+@%w+%.%w+)>")
  info.author_date = advance():match("AuthorDate:%s*(.+)")
  info.committer_name, info.committer_email = advance():match("Commit:%s*(%w+) <(%w+@%w+%.%w+)>")
  info.committer_date = advance():match("CommitDate:%s*(.+)")
  info.description = {}
  
  -- skip empty line
  advance()

  local line = advance()
  while line ~= "" do
    table.insert(info.description, line)
    line = advance()
  end

  -- skip empty line
  advance()

  local raw_diff_info = {}

  local line = advance()
  while line do
    table.insert(raw_diff_info, line)
    line = advance()
  end

  info.diff = parse_diff(raw_diff_info)

  return info
end

--- Creates a new CommitViewBuffer
-- @param commit the oid of the commit
function M.new(commit)
  local instance = {
    is_open = false,
    commit = nil,
    buffer = nil
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:open()
  if self.is_open then
    return
  end

  self.is_open = true
  self.buffer = Buffer.create {
    name = "NeogitCommitView",
    filetype = "NeogitCommitView",
    mappings = {},
    initialize = function(buffer)
      buffer:set_lines(0, -1, false, { "Hello World" })
    end
  }
end

inspect(parse_commit_info(cli.show.format("fuller").args("HEAD^1").call_sync()))

return M
