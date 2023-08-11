local M = {}

local a = require("plenary.async")
local git = require("neogit.lib.git")
local client = require("neogit.client")
local notif = require("neogit.lib.notification")
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

local function build_commit_message(commits)
  local message = {}
  table.insert(message, string.format("Revert %d commits\n", #commits))

  for _, commit in ipairs(commits) do
    table.insert(message, string.format("%s '%s'", commit:sub(1, 7), git.log.message(commit)))
  end

  return table.concat(message, "\n") .. "\04"
end

function M.commits(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  local args = popup:get_arguments()
  local success = git.revert.commits(commits, args)
  if not success then
    notif.create("Revert failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
    return
  end

  local commit_cmd = git.cli.commit.no_verify.with_message(build_commit_message(commits))
  if vim.tbl_contains(args, "--edit") then
    commit_cmd = commit_cmd.edit
  else
    commit_cmd = commit_cmd.no_edit
  end

  client.wrap(commit_cmd, {
    autocmd = "NeogitRevertComplete",
    refresh = "do_revert",
    msg = {
      setup = "Reverting...",
      success = "Reverted!",
      fail = "Couldn't revert",
    },
  })

  a.util.scheduler()
  require("neogit.status").refresh(true, "revert_commits")
end

function M.changes(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  git.revert.commits(commits, popup:get_arguments())
  a.util.scheduler()
  require("neogit.status").refresh(true, "revert_changes")
end

function M.continue()
  git.revert.continue()
  a.util.scheduler()
  require("neogit.status").refresh(true, "revert_continue")
end

function M.skip()
  git.revert.skip()
  a.util.scheduler()
  require("neogit.status").refresh(true, "revert_skip")
end

function M.abort()
  git.revert.abort()
  a.util.scheduler()
  require("neogit.status").refresh(true, "revert_abort")
end

return M
