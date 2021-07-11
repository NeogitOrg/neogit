local M = {}

local Ui = require 'neogit.lib.ui'
local util = require 'neogit.lib.util'
local common_ui = require 'neogit.buffers.common'

local Diff = common_ui.Diff
local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map
local intersperse = util.intersperse

function M.OverviewFile(file)
  return row.tag("OverviewFile") {
    text.highlight("NeogitFilePath")(file.path),
    text " | " ,
    text.highlight("Number")(file.changes),
    text " " ,
    text.highlight("NeogitDiffAdd")(file.insertions),
    text.highlight("NeogitDiffDelete")(file.deletions),
  }
end

function M.CommitHeader(info)
  return col {
    text.sign("NeogitCommitViewHeader")("Commit " .. info.oid),
    text("Author:     " .. info.author_name .. " <" .. info.author_email .. ">"),
    text("AuthorDate: " .. info.author_date),
    text("Commit:     " .. info.committer_name .. " <" .. info.committer_email .. ">"),
    text("CommitDate: " .. info.committer_date),
  }
end

function M.CommitView(info, overview)
  return {
    M.CommitHeader(info),
    text "" ,
    col(map(info.description, text), { sign = "NeogitCommitViewDescription", tag = "Description" }),
    text "",
    text(overview.summary),
    col(map(overview.files, M.OverviewFile), { tag = "OverviewFileList" }),
    text "",
    col(intersperse(map(info.diffs, Diff), text("")), { tag = "DiffList" })
  }
end

return M
