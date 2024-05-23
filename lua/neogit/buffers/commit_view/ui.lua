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
    text("  | "),
    text.highlight("Number")(util.pad_left(file.changes, 5)),
    text("  "),
    text.highlight("NeogitDiffAdditions")(file.insertions),
    text.highlight("NeogitDiffDeletions")(file.deletions),
  }
end

local function commit_header_arg(info)
  if info.oid ~= info.commit_arg then
    return row { text(info.commit_arg .. " "), text.highlight("NeogitObjectId")(info.oid) }
  else
    return row {}
  end
end

function M.CommitHeader(info)
  return col {
    text.line_hl("NeogitCommitViewHeader")("Commit " .. info.commit_arg),
    commit_header_arg(info),
    row {
      text.highlight("NeogitSubtleText")("Author:     "),
      text((info.author_name or "") .. " <" .. (info.author_email or "") .. ">"),
    },
    row { text.highlight("NeogitSubtleText")("AuthorDate: "), text(info.author_date) },
    row {
      text.highlight("NeogitSubtleText")("Committer:  "),
      text((info.committer_name or "") .. " <" .. (info.committer_email or "") .. ">"),
    },
    row { text.highlight("NeogitSubtleText")("CommitDate: "), text(info.committer_date) },
  }
end

function M.SignatureBlock(signature_block)
  if vim.tbl_isempty(signature_block or {}) then
    return text("")
  end

  return col(util.merge(map(signature_block, text), { text("") }), { tag = "Signature" })
end

function M.CommitView(info, overview, signature_block, item_filter)
  if item_filter then
    overview.files = util.filter_map(overview.files, function(file)
      if vim.tbl_contains(item_filter, vim.trim(file.path)) then
        return file
      end
    end)

    info.diffs = util.filter_map(info.diffs, function(diff)
      if vim.tbl_contains(item_filter, vim.trim(diff.file)) then
        return diff
      end
    end)
  end

  return {
    M.CommitHeader(info),
    text(""),
    col(map(info.description, text), { highlight = "NeogitCommitViewDescription", tag = "Description" }),
    text(""),
    M.SignatureBlock(signature_block),
    text(overview.summary),
    col(map(overview.files, M.OverviewFile), { tag = "OverviewFileList" }),
    text(""),
    col(map(info.diffs, Diff), { tag = "DiffList" }),
  }
end

return M
