local M = {}

local a = require("plenary.async")
local git = require("neogit.lib.git")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

-- .git/sequencer/todo does not exist when there is only one commit left.
--
-- And CHERRY_PICK_HEAD does not exist when a conflict happens while picking a series of commits with --no-commit.
-- And REVERT_HEAD does not exist when a conflict happens while reverting a series of commits with --no-commit.
--
function M.pick_or_revert_in_progress()
  local pick_or_revert_todo = false

  for _, item in ipairs(git.repo.cherry_pick.items) do
    if item.name:match("^pick") or item.name:match("^revert") then
      pick_or_revert_todo = true
      break
    end
  end

  return git.repo.cherry_pick.head or pick_or_revert_todo
end

function M.pick(popup)
  local commits
  if popup.state.env.commits then
    commits = popup.state.env.commits
  else
    commits = { CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async() }
  end

  if not commits or not commits[1] then
    return
  end

  git.cherry_pick.pick(commits, popup:get_arguments())

  a.util.scheduler()
  require("neogit.status").refresh(true, "cherry_pick_pick")
end

function M.apply(popup)
  local commits
  if popup.state.env.commits then
    commits = popup.state.env.commits
  else
    commits = { CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async() }
  end

  if not commits or not commits[1] then
    return
  end

  git.cherry_pick.apply(commits, popup:get_arguments())

  a.util.scheduler()
  require("neogit.status").refresh(true, "cherry_pick_apply")
end

function M.continue()
  git.cherry_pick.continue()
  a.util.scheduler()
  require("neogit.status").refresh(true, "cherry_pick_continue")
end

function M.skip()
  git.cherry_pick.skip()
  a.util.scheduler()
  require("neogit.status").refresh(true, "cherry_pick_skip")
end

function M.abort()
  git.cherry_pick.abort()
  a.util.scheduler()
  require("neogit.status").refresh(true, "cherry_pick_abort")
end

return M
