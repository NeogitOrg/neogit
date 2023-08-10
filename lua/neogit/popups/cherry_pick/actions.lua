local M = {}

local a = require("plenary.async")
local git = require("neogit.lib.git")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

---@param popup any
---@return table
local function get_commits(popup)
  local commits
  if popup.state.env.commits[1] then
    commits = popup.state.env.commits
  else
    commits = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
  end

  return commits or {}
end

function M.pick(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  a.util.scheduler()
  git.cherry_pick.pick(commits, popup:get_arguments())

  a.util.scheduler()
  require("neogit.status").refresh(true, "cherry_pick_pick")
end

function M.apply(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  a.util.scheduler()
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
