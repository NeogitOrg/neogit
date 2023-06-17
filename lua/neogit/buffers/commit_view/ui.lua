local M = {}

local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")
local common_ui = require("neogit.buffers.common")

local Diff = common_ui.Diff
local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

function M.OverviewFile(file)
  return row.tag("OverviewFile") {
    text.highlight("NeogitFilePath")(file.path),
    text(" | "),
    text.highlight("Number")(file.changes),
    text(" "),
    text.highlight("NeogitDiffAdd")(file.insertions),
    text.highlight("NeogitDiffDelete")(file.deletions),
  }
end

function M.CommitHeader(info)
  return col {
    text.sign("NeogitCommitViewHeader")("Commit " .. info.oid),
    row {
      text.highlight("Comment")("Author:     "),
      text(info.author_name .. " <" .. info.author_email .. ">"),
    },
    row { text.highlight("Comment")("AuthorDate: "), text(info.author_date) },
    row {
      text.highlight("Comment")("Committer:  "),
      text(info.committer_name .. " <" .. info.committer_email .. ">"),
    },
    row { text.highlight("Comment")("CommitDate: "), text(info.committer_date) },
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
    col(map(info.diffs, Diff), { tag = "DiffList" }),
  }
end

return M
