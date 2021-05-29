local M = {}

local Ui = require 'neogit.lib.ui'
local util = require 'neogit.lib.util'

local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map
local intersperse = util.intersperse
local range = util.range

local diff_add_matcher = vim.regex('^+')
local diff_delete_matcher = vim.regex('^-')

function M.OverviewFile(file)
  return row({
    text(file.path, { highlight = "NeogitFilePath" }),
    text(" | "),
    text(file.changes, { highlight = "Number" }),
    text(" "),
    text(file.insertions, { highlight = "NeogitDiffAdd" }),
    text(file.deletions, { highlight = "NeogitDiffDelete" }),
  }, { tag = "OverviewFile" })
end

function M.Diff(diff)
  return col({
    text(diff.kind, " ", diff.file),
    col(map(diff.hunks, function(hunk) 
      return M.Hunk(diff, hunk)
    end), { tag = "HunkList" })
  }, { tag = "Diff" })
end

function M.Hunk(diff, hunk)
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
    end), { tag = "HunkContent" })
  }, { tag = "Hunk"})
end

function M.CommitHeader(info)
  return col {
    text("Commit ", info:abbrev(), { sign = "NeogitCommitViewHeader" }),
    text("<remote>/<branch> ", info.oid),
    text("Author:     ", info.author_name, " <", info.author_email, ">"),
    text("AuthorDate: ", info.author_date),
    text("Commit:     ", info.committer_name, " <", info.committer_email, ">"),
    text("CommitDate: ", info.committer_date),
  }
end

function M.CommitView(info, overview)
  return {
    M.CommitHeader(info),
    text(""),
    col(map(info.description, text), { sign = "NeogitCommitViewDescription", tag = "Description" }),
    text(""),
    text(overview.summary),
    col(map(overview.files, M.OverviewFile), { tag = "OverviewFileList" }),
    text(""),
    col(intersperse(map(info.diffs, M.Diff), text("")), { tag = "DiffList" })
  }
end

return M
