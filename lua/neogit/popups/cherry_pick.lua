-- https://magit.vc/manual/2.11.0/magit/Cherry-Picking.html#Cherry-Picking
local cherry_pick = require("neogit.lib.git.cherry_pick")
local popup = require("neogit.lib.popup")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local log = require("neogit.lib.git.log")
local util = require("neogit.lib.util")

local M = {}
local a = require("plenary.async")

-- .git/sequencer/todo does not exist when there is only one commit left.
--
-- And CHERRY_PICK_HEAD does not exist when a conflict happens while picking a series of commits with --no-commit.
-- And REVERT_HEAD does not exist when a conflict happens while reverting a series of commits with --no-commit.
--
local function pick_or_revert_in_progress(status)
  local pick_or_revert_todo = false

  for _, item in ipairs(status.repo.cherry_pick.items) do
    if item.name:match("^pick") or item.name:match("^revert") then
      pick_or_revert_todo = true
      break
    end
  end

  return status and (status.repo.cherry_pick.head or pick_or_revert_todo)
end

function M.create(env)
  local status = require("neogit.status")
  local p = popup
    .builder()
    :name("NeogitCherryPickPopup")
    :switch("F", "ff", "Attempt fast-forward", { enabled = true })
    -- :switch("x", "x", "Reference cherry in commit message", { cli_prefix = "-" })
    -- :switch("e", "edit", "Edit commit messages", false)
    -- :switch("s", "signoff", "Add Signed-off-by lines", false)
    -- :option("m", "mainline", "", "Replay merge relative to parent")
    -- :option("s", "strategy", "", "Strategy")
    -- :option("S", "gpg-sign", "", "Sign using gpg")
    :group_heading_if(not pick_or_revert_in_progress(status), "Apply here")
    :action_if(not pick_or_revert_in_progress(status), "A", "Pick", function(popup)
      local commits
      if popup.state.env.commits then
        commits = popup.state.env.commits
      else
        commits = { CommitSelectViewBuffer.new(log.list_extended()):open_async() }
      end

      if not commits or not commits[1] then
        return
      end

      cherry_pick.pick(commits, popup:get_arguments())

      a.util.scheduler()
      status.refresh(true, "cherry_pick_pick")
    end)
    :action_if(not pick_or_revert_in_progress(status), "a", "Apply", function(popup)
      local commits
      if popup.state.env.commits then
        commits = popup.state.env.commits
      else
        commits = { CommitSelectViewBuffer.new(log.list_extended()):open_async() }
      end

      if not commits or not commits[1] then
        return
      end

      cherry_pick.apply(commits, popup:get_arguments())

      a.util.scheduler()
      status.refresh(true, "cherry_pick_apply")
    end)
    :action_if(not pick_or_revert_in_progress(status), "h", "Harvest", false)
    :action_if(not pick_or_revert_in_progress(status), "m", "Squash", false)
    :new_action_group_if(not pick_or_revert_in_progress(status), "Apply elsewhere")
    :action_if(not pick_or_revert_in_progress(status), "d", "Donate", false)
    :action_if(not pick_or_revert_in_progress(status), "n", "Spinout", false)
    :action_if(not pick_or_revert_in_progress(status), "s", "Spinoff", false)
    :group_heading_if(pick_or_revert_in_progress(status), "Cherry Pick")
    :action_if(pick_or_revert_in_progress(status), "A", "continue", function()
      cherry_pick.continue()
      a.util.scheduler()
      status.refresh(true, "cherry_pick_continue")
    end)
    :action_if(pick_or_revert_in_progress(status), "s", "skip", function()
      cherry_pick.skip()
      a.util.scheduler()
      status.refresh(true, "cherry_pick_skip")
    end)
    :action_if(pick_or_revert_in_progress(status), "a", "abort", function()
      cherry_pick.abort()
      a.util.scheduler()
      status.refresh(true, "cherry_pick_abort")
    end)
    :env({ commits = env.commits })
    :build()

  p:show()

  return p
end

return M
