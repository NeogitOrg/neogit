local M = {}

local a = require("plenary.async")
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
  ["+"] = "NeogitGraphCyan",
  ["-"] = "NeogitGraphPurple",
  ["<>"] = "NeogitGraphYellow",
  ["="] = "NeogitGraphGreen",
  ["<"] = "NeogitGraphPurple",
  [">"] = "NeogitGraphCyan",
  [""] = "NeogitGraphRed",
}

local function Cherries(ref, head)
  local cherries = util.map(git.cherry.list(head, ref.oid), function(cherry)
    return row({
      text.highlight(highlights[cherry.status])(cherry.status),
      text(" "),
      text.highlight("NeogitObjectId")(cherry.oid:sub(1, git.log.abbreviated_size())),
      text(" "),
      text.highlight("NeogitGraphWhite")(cherry.subject),
    }, { oid = cherry.oid })
  end)

  if cherries[1] then
    table.insert(cherries, row { text("") })
  end

  return col.padding_left(2)(cherries)
end

local function Ref(ref)
  return row {
    text.highlight("NeogitGraphBoldPurple")(ref.head and "@ " or "  "),
    text.highlight(highlights[ref.type])(util.str_truncate(ref.name, 34), { align_right = 35 }),
    text.highlight(highlights[ref.upstream_status])(ref.upstream_name),
    text(ref.upstream_name ~= "" and " " or ""),
    text(ref.subject),
  }
end

local function section(refs, heading, head)
  local rows = {}
  for _, ref in ipairs(refs) do
    table.insert(
      rows,
      col.tag("Ref")({ Ref(ref) }, {
        oid = ref.oid,
        ref = ref,
        foldable = true,
        ---@param this Component
        ---@param ui Ui
        on_open = a.void(function(this, ui)
          vim.cmd(
            string.format("echomsg 'Getting cherries for %s'", ref.oid:sub(1, git.log.abbreviated_size()))
          )

          local cherries = Cherries(ref, head)
          if cherries.children[1] then
            this.options.on_open = nil -- Don't call this again
            this.options.foldable = true
            this.options.folded = false
            this.options.ref = ref

            vim.cmd("norm! zE") -- Eliminate all existing folds
            this:append(cherries)
            ui:update()

            vim.cmd(
              string.format(
                "redraw | echomsg 'Got %d cherries for %s'",
                #cherries.children - 1,
                ref.oid:sub(1, git.log.abbreviated_size())
              )
            )
          else
            vim.cmd(
              string.format(
                "redraw | echomsg 'No cherries found for %s'",
                ref.oid:sub(1, git.log.abbreviated_size())
              )
            )
          end
        end),
      })
    )
  end

  table.insert(rows, row { text("") })

  return col.tag("Section")({
    row.tag("SectionHeading")(
      util.merge(heading, { text.highlight("NeogitGraphWhite")(string.format(" (%d)", #refs)) })
    ),
    col.tag("SectionBody")(rows),
  }, { foldable = true, folded = false })
end

function M.Branches(branches, head)
  return { section(branches, { text.highlight("NeogitBranch")("Branches") }, head) }
end

local function sorted_names(remotes)
  local remote_names = {}
  for name, _ in pairs(remotes) do
    table.insert(remote_names, name)
  end
  table.sort(remote_names)

  return remote_names
end

function M.Remotes(remotes, head)
  local out = {}
  local max_len = util.max_length(vim.tbl_keys(remotes))

  for _, name in pairs(sorted_names(remotes)) do
    local branches = remotes[name]
    table.insert(
      out,
      section(branches, {
        text.highlight("NeogitBranch")("Remote "),
        text.highlight("NeogitRemote")(name, { align_right = max_len }),
        text.highlight("NeogitBranch")(
          string.format(" (%s)", git.config.get_local(string.format("remote.%s.url", name)):read())
        ),
      }, head)
    )
  end

  return out
end

function M.Tags(tags, head)
  return { section(tags, { text.highlight("NeogitBranch")("Tags") }, head) }
end

function M.RefsView(refs, head)
  return util.merge(
    M.Branches(refs.local_branch, head),
    M.Remotes(refs.remote_branch, head),
    M.Tags(refs.tag, head)
  )
end

return M
