-- TODO
-- - When a section is collapsed, there should not be an empty line between it and the next section
-- - Get fold markers to work
--
--
-- Rule! No external state!
--
local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")
local common = require("neogit.buffers.common")
local a = require("plenary.async")

local col = Ui.col
local row = Ui.row
local text = Ui.text

local map = util.map

local List = common.List
local DiffHunks = common.DiffHunks
local EmptyLine = col({ row { text("") } })

local M = {}

local HEAD = Component.new(function(props)
  local highlight = props.remote and "NeogitRemote" or "NeogitBranch"
  local ref = props.remote and ("%s/%s"):format(props.remote, props.branch) or props.branch

  return row({
    text(util.pad_right(props.name .. ":", 10)),
    text.highlight(highlight)(ref),
    text(" "),
    text(props.msg or "(no commits)"),
  }, { yankable = props.yankable })
end)

local Tag = Component.new(function(props)
  return row({
    text(util.pad_right("Tag:", 10)),
    text.highlight("NeogitTagName")(props.name),
    text(" ("),
    text.highlight("NeogitTagDistance")(props.distance),
    text(")"),
  }, { yankable = props.yankable })
end)

local SectionTitle = Component.new(function(props)
  return { text.highlight("NeogitSectionHeader")(props.title) }
end)

local SectionTitleRemote = Component.new(function(props)
  return {
    text.highlight("NeogitSectionHeader")(props.title),
    text(" "),
    text.highlight("NeogitRemote")(props.ref)
  }
end)

local Section = Component.new(function(props)
  return col.tag("Section")({
    row(
      util.merge(
        props.title,
        { text(" ("), text(#props.items), text(")"), }
      )
    ),
    col(map(props.items, props.render)),
    EmptyLine,
  }, { foldable = true, folded = props.folded, section = props.name })
end)

local load_diff = function(item)
  return a.void(function(this, ui)
    this.options.on_open = nil
    this.options.folded = false
    -- vim.cmd("norm! zE") -- Eliminate all existing folds
    this:append(DiffHunks(item.diff))
    ui:update()
  end)
end

local SectionItemFile = Component.new(function(item)
  local mode_to_text = {
    M  = "Modified      ",
    N  = "New File      ",
    A  = "Added         ",
    D  = "Deleted       ",
    C  = "Copied        ",
    U  = "Updated       ",
    UU = "Both Modified ",
    R  = "Renamed       ",
    ["?"] = "", -- Untracked
  }

  local conflict = false
  local mode = mode_to_text[item.mode]
  if mode == nil then
    conflict = true
    mode = mode_to_text[item.mode:sub(1, 1)]
  end

  local highlight = ("NeogitChange%s"):format(mode:gsub(" ", ""))

  return col.tag("SectionItemFile")({
    row {
      text.highlight(highlight)(conflict and ("%s by us"):format(mode) or mode),
      text(item.name)
    }
  }, {
    foldable = true,
    folded = true,
    on_open = load_diff(item),
    context = true,
    yankable = item.name,
    filename = item.name,
    item = item,
  })
end)

local SectionItemStash = Component.new(function(item)
  local name = ("stash@{%s}"):format(item.idx)
  return row({
    text.highlight("Comment")(name),
    text.highlight("Comment")(": "),
    text(item.message),
  }, { yankable = name })
end)

local SectionItemCommit = Component.new(function(item)
  return row({
    text.highlight("Comment")(item.commit.abbreviated_commit),
    text(" "),
    text(item.commit.subject),
  }, { yankable = item.commit.oid })
end)

-- TODO: Hint at top of buffer!
function M.Status(state, config)
  return {
    List {
      items = {
        HEAD {
          name = "Head",
          branch = state.head.branch,
          msg = state.head.commit_message,
          yankable = state.head.oid,
        },
        state.upstream.ref and HEAD { -- Do not render if HEAD is detached
          name = "Merge",
          branch = state.upstream.branch,
          remote = state.upstream.remote,
          msg = state.upstream.commit_message,
          yankable = state.upstream.oid,
        },
        state.pushRemote.ref and HEAD {  -- Do not render if HEAD is detached
          name = "Push",
          branch = state.pushRemote.branch,
          remote = state.pushRemote.remote,
          msg = state.pushRemote.commit_message,
          yankable = state.pushRemote.oid,
        },
        state.head.tag.name and Tag {
          name = state.head.tag.name,
          distance = state.head.tag.distance,
          yankable = state.head.tag.oid,
        },
        EmptyLine,
        -- TODO Rebasing (rebase)
        -- TODO Reverting (sequencer - revert_head)
        -- TODO Picking (sequencer - cherry_pick_head)
        -- TODO Respect if user has section hidden
        #state.untracked.items > 0 and Section { -- TODO: Group by directory and create a fold
          title = SectionTitle({ title = "Untracked files" }),
          render = SectionItemFile,
          items = state.untracked.items,
          folded = config.sections.untracked.folded,
          name = "untracked",
        },
        #state.unstaged.items > 0 and Section {
          title = SectionTitle({ title = "Unstaged changes" }),
          render = SectionItemFile,
          items = state.unstaged.items,
          folded = config.sections.unstaged.folded,
          name = "unstaged",
        },
        #state.staged.items > 0 and Section {
          title = SectionTitle({ title = "Staged changes" }),
          render = SectionItemFile,
          items = state.staged.items,
          folded = config.sections.staged.folded,
          name = "staged",
        },
        #state.upstream.unpulled.items > 0 and Section {
          title = SectionTitleRemote({ title = "Unpulled from", ref = state.upstream.ref }),
          render = SectionItemCommit,
          items = state.upstream.unpulled.items,
          folded = config.sections.unpulled_upstream.folded,
        },
        (#state.pushRemote.unpulled.items > 0 and state.pushRemote.ref ~= state.upstream.ref) and Section {
          title = SectionTitleRemote({ title = "Unpulled from", ref = state.pushRemote.ref }),
          render = SectionItemCommit,
          items = state.pushRemote.unpulled.items,
          folded = config.sections.unpulled_pushRemote.folded,
        },
        #state.upstream.unmerged.items > 0 and Section {
          title = SectionTitleRemote({ title = "Unmerged into", ref = state.upstream.ref }),
          render = SectionItemCommit,
          items = state.upstream.unmerged.items,
          folded = config.sections.unmerged_upstream.folded,
        },
        (#state.pushRemote.unmerged.items > 0 and state.pushRemote.ref ~= state.upstream.ref) and Section {
          title = SectionTitleRemote({ title = "Unpushed to", ref = state.pushRemote.ref }),
          render = SectionItemCommit,
          items = state.pushRemote.unmerged.items,
          folded = config.sections.unmerged_pushRemote.folded,
        },
        #state.stashes.items > 0 and Section {
          title = SectionTitle({ title = "Stashes" }),
          render = SectionItemStash,
          items = state.stashes.items,
          folded = config.sections.stashes.folded,
        },
        #state.recent.items > 0 and Section {
          title = SectionTitle({ title = "Recent Commits" }),
          render = SectionItemCommit,
          items = state.recent.items,
          folded = config.sections.recent.folded,
        },
      },
    },
  }
end

M._TEST = a.void(function()
  local git = require("neogit.lib.git")
  local config = require("neogit.config")
  git.repo:refresh {
    source = "status_test",
    callback = function()
      require("neogit.buffers.status").new(git.repo, config.values):open()
    end
  }
end)

return M
