local Buffer = require("neogit.lib.buffer")
local cli = require 'neogit.lib.git.cli'
local diff_lib = require('neogit.lib.git.diff')
local LineBuffer = require('neogit.lib.line_buffer')

local diff_add_matcher = vim.regex('^+')
local diff_delete_matcher = vim.regex('^-')

-- @class CommitInfoSummaryFile
-- @field path the path to the file relative to the git root
-- @field insertions how many lines were inserted
-- @field deletions how many lines were deleted

-- @class CommitInfoSummary
-- @field files_changed how many files were changed
-- @field insertions how many lines were inserted
-- @field deletions how many lines were deleted
-- @field files a list of CommitInfoSummaryFile
-- @see CommitInfoSummaryFile

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
-- @field summary CommitInfoSummary
-- @see Diff
-- @see CommitInfoSummary
local CommitInfo = {}

-- @return the abbreviation of the oid
function CommitInfo:abbrev()
  return self.oid:sub(1, 7)
end

local M = {}

local function parse_commit_info(raw_info)
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
  info.diffs = {}
  
  -- skip empty line
  advance()

  local line = advance()
  while line ~= "" do
    table.insert(info.description, vim.trim(line))
    line = advance()
  end

  local raw_diff_info = {}

  local line = advance()
  while line do
    table.insert(raw_diff_info, line)
    line = advance()
    if line == nil or vim.startswith(line, "diff") then
      local diff = diff_lib.parse(raw_diff_info)
      diff.stats = diff_lib.get_stats(diff.file)
      table.insert(info.diffs, diff)
      raw_diff_info = {}
    end
  end

  info.summary = {
    files_changed = #info.diffs,
    insertions = 0,
    deletions = 0,
    files = {}
  }

  for _, diff in ipairs(info.diffs) do
    info.summary.insertions = info.summary.insertions + diff.stats.additions
    info.summary.deletions = info.summary.deletions + diff.stats.deletions
    table.insert(info.summary.files, {
      path = diff.file,
      insertions = diff.stats.additions,
      deletions = diff.stats.deletions
    })
  end

  setmetatable(info, { __index = CommitInfo })

  return info
end

-- @class CommitViewBuffer
-- @field is_open whether the buffer is currently shown
-- @field commit_info CommitInfo
-- @field buffer Buffer
-- @see CommitInfo
-- @see Buffer

--- Creates a new CommitViewBuffer
-- @param commit_id the id of the commit
-- @return CommitViewBuffer
function M.new(commit_id)
  local instance = {
    is_open = false,
    commit_info = parse_commit_info(cli.show.format("fuller").args(commit_id).call_sync()),
    buffer = nil
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end

function M:open()
  if self.is_open then
    return
  end

  self.is_open = true
  self.buffer = Buffer.create {
    name = "NeogitCommitView",
    filetype = "NeogitCommitView",
    kind = "vsplit",
    mappings = {
      n = {
        ["q"] = function()
          self:close()
        end
      }
    },
    initialize = function(buffer)
      local output = LineBuffer.new()
      local info = self.commit_info
      local signs = {}
      local highlights = {}

      local function add_sign(name)
        signs[#output] = name
      end

      local function add_highlight(from, to, name)
        table.insert(highlights, { 
          line = #output - 1, 
          from = from, 
          to = to,
          name = name
        })
      end
      
      output:append("Commit " .. info:abbrev())
      add_sign 'NeogitCommitViewHeader'
      output:append("<remote>/<branch> " .. info.oid)
      output:append("Author:     " .. info.author_name .. " <" .. info.author_email .. ">")
      output:append("AuthorDate: " .. info.author_date)
      output:append("Commit:     " .. info.committer_name .. " <" .. info.committer_email .. ">")
      output:append("CommitDate: " .. info.committer_date)
      output:append("")
      for _, line in ipairs(info.description) do
        output:append(line)
        add_sign 'NeogitCommitViewDescription'
      end
      output:append("")
      output:append(
        info.summary.files_changed .. ((info.summary.files_changed > 1) and " files changed, " or " file changed, ") .. 
        info.summary.insertions .. " insertions(+), " .. 
        info.summary.deletions .. " deletions(+)"
      )
      for _, file in ipairs(info.summary.files) do
        local changes = file.insertions + file.deletions
        output:append(
          file.path .. " | " .. changes .. 
          " " .. string.rep("+", file.insertions) .. string.rep("-", file.deletions)
        )
        local from = 0
        local to = #file.path
        add_highlight(from, to, "NeogitFilePath")
        from = to + 3
        to = from + #tostring(changes)
        add_highlight(from, to, "Number")
        from = to + 1
        to = from + file.insertions
        add_highlight(from, to, "NeogitDiffAdd")
        from = to
        to = from + file.deletions
        add_highlight(from, to, "NeogitDiffDelete")
      end
      for _, diff in ipairs(info.diffs) do
        output:append("")
        output:append("<kind> " .. diff.file)
        for _, hunk in ipairs(diff.hunks) do
          output:append(diff.lines[hunk.diff_from])
          add_sign 'NeogitHunkHeader'
          for i=hunk.diff_from + 1, hunk.diff_to do
            local l = diff.lines[i]
            output:append(l)
            if diff_add_matcher:match_str(l) then
              add_sign 'NeogitDiffAdd'
            elseif diff_delete_matcher:match_str(l) then
              add_sign 'NeogitDiffDelete'
            end
          end
        end
      end
      buffer:replace_content_with(output)

      for line, name in pairs(signs) do
        buffer:place_sign(line, name, "hl")
      end

      for _, hi in ipairs(highlights) do
        buffer:add_highlight(
          hi.line,
          hi.from,
          hi.to,
          hi.name
        )
      end
    end
  }
end

M.new("HEAD"):open()

return M
