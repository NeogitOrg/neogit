local Buffer = require("neogit.lib.buffer")
local Ui = require 'neogit.lib.ui'
local util = require 'neogit.lib.util'
local cli = require 'neogit.lib.git.cli'
local diff_lib = require('neogit.lib.git.diff')
local LineBuffer = require('neogit.lib.line_buffer')

local diff_add_matcher = vim.regex('^+')
local diff_delete_matcher = vim.regex('^-')

local text = Ui.text
local col = Ui.col
local row = Ui.row

local map = util.map
local intersperse = util.intersperse
local range = util.range

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

local M = {}

local function parse_commit_overview(raw)
  local overview = { 
    summary = vim.trim(raw[#raw]), 
    files = {}
  }

  for i=2,#raw-1 do
    local file = {}
    file.path, file.changes, file.insertions, file.deletions = raw[i]:match(" (.*)%s+|%s+(%d+) (%+*)(%-*)")
    table.insert(overview.files, file)
  end

  setmetatable(overview, { __index = CommitOverview })

  return overview
end

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
      table.insert(info.diffs, diff_lib.parse(raw_diff_info))
      raw_diff_info = {}
    end
  end

  setmetatable(info, { __index = CommitInfo })

  return info
end

-- @class CommitViewBuffer
-- @field is_open whether the buffer is currently shown
-- @field commit_info CommitInfo
-- @field commit_overview CommitOverview
-- @field buffer Buffer
-- @field ui Ui
-- @see CommitInfo
-- @see Buffer
-- @see Ui

--- Creates a new CommitViewBuffer
-- @param commit_id the id of the commit
-- @return CommitViewBuffer
function M.new(commit_id)
  local instance = {
    is_open = false,
    commit_info = parse_commit_info(cli.show.format("fuller").args(commit_id).call_sync()),
    commit_overview = parse_commit_overview(cli.show.stat.oneline.args(commit_id).call_sync()),
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

function create_file_component(file)
  return row({
    text(file.path, { highlight = "NeogitFilePath" }),
    text(" | "),
    text(file.changes, { highlight = "Number" }),
    text(" "),
    text(file.insertions, { highlight = "NeogitDiffAdd" }),
    text(file.deletions, { highlight = "NeogitDiffDelete" }),
  }, { tag = "CommitViewOverviewFile" })
end

function create_diff_component(diff)
  return col({
    text(diff.kind, " ", diff.file),
    col(map(diff.hunks, function(hunk) 
      return create_hunk_component(diff, hunk)
    end), { tag = "CommitViewDiffHunks" })
  }, { is_diff = true, tag = "CommitViewDiff" })
end

function create_hunk_component(diff, hunk)
  return col({
    text(diff.lines[hunk.diff_from], { sign = "NeogitHunkHeader" }),
    col(map(range(hunk.diff_from + 1, hunk.diff_to), function(i)
      local l = diff.lines[i]
      local sign
      if diff_add_matcher:match_str(l) then
        sign = 'NeogitDiffAdd'
      elseif diff_delete_matcher:match_str(l) then
        sign = 'NeogitDiffDelete'
      end

      return text(l, { sign = sign })
    end))
  }, { is_hunk = true, tag = "CommitViewDiffHunk"})
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
        end,
        ["d"] = function()
          self.ui:print_layout_tree()
        end,
        ["<tab>"] = function()
          local curr_line = vim.api.nvim_win_get_cursor(0)[1]
          local c = self.ui:get_component_under_cursor()
          Ui.visualize_component(c)
          -- local c = self.ui:find_component(function(c)
          --   local from, to = c:row_range_abs()
          --   local contains_line = from <= curr_line and curr_line <= to

          --   return (c.options.is_hunk or c.options.is_diff) and contains_line
          -- end)

          -- if c then
          --   local child = c.children[2]
          --   child.options.hidden = not child.options.hidden
          --   self.ui:update()
          -- end
        end
      }
    },
    initialize = function(buffer)
      local info = self.commit_info
      local overview = self.commit_overview

      self.ui = Ui.new(buffer)

      self.ui:render(
        text("Commit ", info:abbrev(), { sign = "NeogitCommitViewHeader" }),
        text("<remote>/<branch> ", info.oid),
        text("Author:     ", info.author_name, " <", info.author_email, ">"),
        text("AuthorDate: ", info.author_date),
        text("Commit:     ", info.committer_name, " <", info.committer_email, ">"),
        text("CommitDate: ", info.committer_date),
        text(""),
        col(map(info.description, text), { sign = "NeogitCommitViewDescription", tag = "CommitViewDescription" }),
        text(""),
        text(overview.summary),
        col(map(overview.files, create_file_component), { tag = "CommitViewOverviewFiles" }),
        text(""),
        col(intersperse(map(info.diffs, create_diff_component), text("")), { tag = "CommitViewDiffs" })
      )

      -- self.ui:print_layout_tree()
    end
  }
end

function TEST()
  M.new("HEAD"):open()
end

return M
