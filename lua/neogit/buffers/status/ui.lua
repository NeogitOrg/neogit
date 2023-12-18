local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")
local common = require("neogit.buffers.common")

local col = Ui.col
local row = Ui.row
local text = Ui.text

local map = util.map

local List = common.List
local Diff = common.Diff

local M = {}

local RemoteHeader = Component.new(function(props)
  return row {
    text(props.name),
    text(": "),
    text(props.branch),
    text(" "),
    text(props.msg or "(no commits)"),
  }
end)

local Section = Component.new(function(props)
  return col({
    row {
      text(props.title),
      text(" ("),
      text(#props.items),
      text(")"),
    },
    col(props.items),
  }, { foldable = true, folded = false })
end)

function M.Status(state)
  return {
    List {
      separator = " ",
      items = {
        col {
          RemoteHeader {
            name = "Head",
            branch = state.head.branch,
            msg = state.head.commit_message,
          },
          state.upstream.ref and RemoteHeader {
            name = "Upstream",
            branch = state.upstream.ref,
            msg = state.upstream.commit_message,
          },
        },
        #state.untracked.items > 0 and Section {
          title = "Untracked files",
          items = map(state.untracked.items, Diff),
        },
        #state.unstaged.items > 0 and Section {
          title = "Unstaged changes",
          items = map(state.unstaged.items, Diff),
        },
        -- #state.staged.items > 0 and Section {
        --   title = "Staged changes",
        --   items = map(state.staged.items, Diff),
        -- },
        -- #state.stashes.items > 0 and Section {
        --   title = "Stashes",
        --   items = map(state.stashes.items, function(s)
        --     return row {
        --       text.highlight("Comment")("stash@{" .. s.idx .. "}: "),
        --       text(s.message),
        --     }
        --   end),
        -- },
        -- #state.upstream.unpulled.items > 0 and Section {
        --   title = "Unpulled changes",
        --   items = map(state.upstream.unpulled.items, Diff),
        -- },
        -- #state.upstream.unmerged.items > 0 and Section {
        --   title = "Unmerged changes",
        --   items = map(state.upstream.unmerged.items, Diff),
        -- },
      },
    },
  }
end

local a = require("plenary.async")

M._TEST = a.void(function()
  local git = require("neogit.lib.git")

  local render_status = function()
    local git = require("neogit.lib.git")
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
