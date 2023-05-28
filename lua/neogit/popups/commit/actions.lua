local M = {}

local notif = require("neogit.lib.notification")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local git = require("neogit.lib.git")
local a = require("plenary.async")

local function do_commit(popup, cmd)
  a.util.scheduler()

  local notification = notif.create("Committing...", vim.log.levels.INFO, 9999)

  local client = require("neogit.client")
  local envs = client.get_envs_git_editor()

  local result = cmd.env(envs).args(unpack(popup:get_arguments())):in_pty(true).call(true):trim()

  a.util.scheduler()
  if notification then
    notification:delete()
  end

  if result.code == 0 then
    notif.create("Successfully committed!")
    vim.cmd("do <nomodeline> User NeogitCommitComplete")
  end

  a.util.scheduler()

  require("neogit.status").refresh(true, "do_commit")
end

local function commit_special(popup, method)
  local commit = CommitSelectViewBuffer.new(git.log.list()):open_async()
  if not commit then
    return
  end

  a.util.scheduler()
  do_commit(popup, git.cli.commit.args(method, commit))
  a.util.scheduler()

  return commit
end

function M.commit(popup)
  do_commit(popup, git.cli.commit)
end

function M.extend(popup)
  do_commit(popup, git.cli.commit.no_edit.amend)
end

function M.reword(popup)
  do_commit(popup, git.cli.commit.amend.only)
end

function M.amend(popup)
  do_commit(popup, git.cli.commit.amend)
end

function M.fixup(popup)
  commit_special(popup, "--fixup")
end

function M.squash(popup)
  commit_special(popup, "--squash")
end

function M.instant_fixup(popup)
  local commit = commit_special(popup, "--fixup")
  if not commit then
    return
  end

  git.rebase.rebase_interactive(commit .. "~1", "--autosquash")
end

function M.instant_squash(popup)
  local commit = commit_special(popup, "--squash")
  if not commit then
    return
  end

  git.rebase.rebase_interactive(commit .. "~1", "--autosquash")
end

return M
