-- TODO
-- - When a section is collapsed, there should not be an empty line between it and the next section
-- - Get fold markers to work
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

  return row {
    text(util.pad_right(props.name .. ":", 10)),
    text.highlight(highlight)(ref),
    text(" "),
    text(props.msg or "(no commits)"),
  }
end)

local Tag = Component.new(function(props)
  return row {
    text(util.pad_right("Tag:", 10)),
    text.highlight("NeogitTagName")(props.name),
    text(" ("),
    text.highlight("NeogitTagDistance")(props.distance),
    text(")"),
  }
end)

local Section = Component.new(function(props)
  return col.tag("Section")({
    row {
      text.highlight("NeogitSectionHeader")(props.title),
      text(" ("),
      text(#props.items),
      text(")"),
    },
    col(props.items),
    EmptyLine,
  }, { foldable = true, folded = false, fold_adjustment = 1 })
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

  return col.tag("SectionItemFile")({
    row {
      text.highlight(("NeogitChange%s"):format(mode_to_text[item.mode]:gsub(" ", "")))(mode_to_text[item.mode]),
      text.highlight("")(item.name)
    }
  }, { foldable = true, folded = true, on_open = load_diff(item), context = true })
end)

local SectionItemStash = Component.new(function(item)
  return row {
    text.highlight("Comment")(("stash@{%s}: "):format(item.idx)),
    text(item.message),
  }
end)

local SectionItemCommit = Component.new(function(item)
  return row {
    text.highlight("Comment")(item.commit.abbreviated_commit),
    text(" "),
    text(item.commit.subject),
  }
end)

function M.Status(state)
  return {
    List {
      items = {
        col {
          HEAD {
            name = "Head",
            branch = state.head.branch,
            msg = state.head.commit_message,
          },
          state.upstream.ref and HEAD {
            name = "Merge",
            branch = state.upstream.branch,
            remote = state.upstream.remote,
            msg = state.upstream.commit_message,
          },
          state.pushRemote.ref and HEAD {
            name = "Push",
            branch = state.pushRemote.branch,
            remote = state.pushRemote.remote,
            msg = state.pushRemote.commit_message,
          },
          state.head.tag.name and Tag {
            name = state.head.tag.name,
            distance = state.head.tag.distance,
          },
        },
        EmptyLine,
        -- Rebase
        -- Sequencer
        -- Merge
        #state.untracked.items > 0 and Section {
          title = "Untracked files",
          items = map(state.untracked.items, SectionItemFile),
        },
        #state.unstaged.items > 0 and Section {
          title = "Unstaged changes",
          items = map(state.unstaged.items, SectionItemFile),
        },
        #state.staged.items > 0 and Section {
          title = "Staged changes",
          items = map(state.staged.items, SectionItemFile),
        },
        -- #state.upstream.unpulled.items > 0 and Section {
        --   title = "Unpulled changes",
        --   items = map(state.upstream.unpulled.items, Diff),
        -- },
        -- #state.upstream.unmerged.items > 0 and Section {
        --   title = "Unmerged changes",
        --   items = map(state.upstream.unmerged.items, Diff),
        -- },
        #state.stashes.items > 0 and Section {
          title = "Stashes",
          items = map(state.stashes.items, SectionItemStash),
        },
        #state.recent.items > 0 and Section {
          title = "Recent Commits",
          items = map(state.recent.items, SectionItemCommit),
        },
      },
    },
  }
end

local a = require("plenary.async")

M._TEST = a.void(function()
  local git = require("neogit.lib.git")

  local render_status = function()
    require("neogit.buffers.status").new(git.repo):open()
    -- .new({
    --   head = git.repo.head,
    --   upstream = git.repo.upstream,
    --   untracked_files = git.repo.untracked.items,
    --   unstaged_changes = map(git.repo.unstaged.items, function(f)
    --     return f.diff
    --   end),
    --   staged_changes = map(git.repo.staged.items, function(f)
    --     return f.diff
    --   end),
    --   stashes = git.repo.stashes.items,
    --   unpulled_changes = git.repo.upstream.unpulled.items,
    --   unmerged_changes = git.repo.upstream.unmerged.items,
    --   recent_changes = git.repo.recent.items,
    -- })
    -- :open()
  end

  git.repo:refresh { source = "status_test", callback = render_status }
end)

return M
