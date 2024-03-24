local M = {}
local git = require("neogit.lib.git")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local notification = require("neogit.lib.notification")
local a = require("plenary.async")

function M.start(popup)
  if git.status.is_dirty() then
    notification.warn("Cannot bisect with uncommitted changes")
    return
  end

  local commits = git.log.list { "HEAD" }
  local bad_commit = CommitSelectViewBuffer.new(
    commits,
    "Select bad revision with <cr> to start bisecting, or abort with <esc>"
  )
    :open_async()[1]
  if not bad_commit then
    return
  end

  a.util.scheduler() -- Needed for second select buffer to appear
  local good_commit =
    CommitSelectViewBuffer.new(commits, "Select good revision with <cr>, or abort with <esc>"):open_async()[1]
  if not good_commit then
    return
  end

  if git.log.is_ancestor(good_commit, bad_commit) then
    notification.info("Bisecting...")
    git.bisect.start(good_commit, bad_commit, popup:get_arguments())
  else
    local message = ("The %s revision (%s) has to be an ancestor of the %s one (%s)"):format(
      "good",
      good_commit,
      "bad",
      bad_commit
    )
    notification.warn(message)
  end
end

function M.scripted()
  print("scripted")
end

function M.good()
  print("good")
end

function M.bad()
  print("bad")
end

function M.skip()
  print("skip")
end

function M.reset()
  print("reset")
end

function M.run_script()
  print("run_script")
end

return M
