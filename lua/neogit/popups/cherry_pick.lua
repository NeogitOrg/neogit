-- https://magit.vc/manual/2.11.0/magit/Cherry-Picking.html#Cherry-Picking
local cherry_pick = require("neogit.lib.git.cherry_pick")
local popup = require("neogit.lib.popup")
local fs = require("neogit.lib.fs")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

local M = {}
local a = require("plenary.async")

-- .git/sequencer/todo does not exist when there is only one commit left.
-- And CHERRY_PICK_HEAD does not exist when a conflict happens while picking a series of commits with --no-commit.
local function pick_in_progress()
  local todo = fs.git_dir("^todo", "/sequencer$")
  local picks = {}
  if todo then
    picks = fs.line_match(todo, "^pick")
  end

  return fs.git_dir("CHERRY_PICK_HEAD") or (todo and picks[1])
end

-- .git/sequencer/todo does not exist when there is only one commit left.
-- And REVERT_HEAD does not exist when a conflict happens while reverting a series of commits with --no-commit.
local function revert_in_progress()
  local todo = fs.git_dir("^todo", "/sequencer$")
  local reverts = {}
  if todo then
    reverts = fs.line_match(todo, "^revert")
  end

  return fs.git_dir("REVERT_HEAD") or (todo and reverts[1])
end

local function pick_or_revert_in_progress()
  return pick_in_progress() or revert_in_progress()
end

function M.create(commit)
  local status = require("neogit.status")
  local p = popup
    .builder()
    :name("NeogitCherryPickPopup")
    :action_if(not pick_or_revert_in_progress(), "A", "pick", a.void(function(popup)
      local commit
      if popup.state.env.commit.hash then
        commit = popup.state.env.commit.hash
      else
        local commits = require("neogit.lib.git.log").list()
        commit = CommitSelectViewBuffer.new(commits):open_async()
      end

      if not commit then
        return
      end

      cherry_pick.pick(commit.oid)

      a.util.scheduler()
      status.refresh(true, "cherry_pick_pick")
    end))
    :action_if(not pick_or_revert_in_progress(), "a", "apply", a.void(function(popup)
      local commit
      if popup.state.env.commit.hash then
        commit = popup.state.env.commit.hash
      else
        local commits = require("neogit.lib.git.log").list()
        commit = CommitSelectViewBuffer.new(commits):open_async()
      end

      if not commit then
        return
      end

      cherry_pick.apply(commit.oid)

      a.util.scheduler()
      status.refresh(true, "cherry_pick_apply")
    end))
    :action_if(pick_or_revert_in_progress(), "A", "continue", function()
      cherry_pick.continue()
      a.util.scheduler()
      status.refresh(true, "cherry_pick_continue")
    end)
    :action_if(pick_or_revert_in_progress(), "s", "skip", function()
      cherry_pick.skip()
      a.util.scheduler()
      status.refresh(true, "cherry_pick_skip")
    end)
    :action_if(pick_or_revert_in_progress(), "a", "abort", function()
      cherry_pick.abort()
      a.util.scheduler()
      status.refresh(true, "cherry_pick_abort")
    end)
    :env({ commit = commit })
    :build()

  p:show()

  return p
end

return M
