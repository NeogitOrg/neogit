local M = {}

local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")

local text = Ui.text
local col = Ui.col
local row = Ui.row

local highlights = {
  local_branch = "NeogitBranch",
  remote_branch = "NeogitRemote",
  tag = "NeogitTagName",
}

local function section(refs, heading)
  local rows = {}
  for _, ref in ipairs(refs) do
    table.insert(
      rows,
      row({
        text.highlight(highlights[ref.type])(
          util.str_truncate(ref.name, 34),
          { align_right = 35 }
        ),
        text(ref.subject),
      }, { oid = ref.oid })
    )
  end

  table.insert(rows, row({ text("") }))

  return col({
    row(util.merge(heading, {
      text.highlight("NeogitGraphWhite")(string.format(" (%d)", #refs)),
    })),
    col.padding_left(2)(rows),
  }, { foldable = true })
end

function M.Branches(branches)
  return section(branches, { text.highlight("NeogitBranch")("Branches") })
end

function M.Remotes(remotes)
  local out = {}
  local max_len = util.max_length(vim.tbl_keys(remotes))

  for name, branches in pairs(remotes) do
    table.insert(
      out,
      section(branches, {
        text.highlight("NeogitBranch")("Remote "),
        text.highlight("NeogitRemote")(name, { align_right = max_len }),
        text.highlight("NeogitBranch")(
          string.format(" (%s)", git.config.get(string.format("remote.%s.url", name)):read())
        ),
      })
    )
  end

  return out
end

function M.Tags(tags)
  return section(tags, { text.highlight("NeogitBranch")("Tags") })
end

function M.RefsView(refs)
  refs = refs or git.refs.list_parsed()

  return util.merge({ M.Branches(refs.local_branch) }, M.Remotes(refs.remote_branch), { M.Tags(refs.tag) })
end

return M
