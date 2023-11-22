local M = {}

local git = require("neogit.lib.git")
local client = require("neogit.client")
local notification = require("neogit.lib.notification")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

---@param popup any
---@return CommitLogEntry[]
local function get_commits(popup)
  local commits
  if #popup.state.env.commits > 0 then
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
  if #commits == 0 then
    return
  end

  local args = popup:get_arguments()

  local success = git.revert.commits(commits, args)

  if not success then
    notification.error("Revert failed. Resolve conflicts before continuing")
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
      success = "Reverted",
    },
  })
end

function M.changes(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  git.revert.commits(commits, popup:get_arguments())
end

function M.continue()
  git.revert.continue()
end

function M.skip()
  git.revert.skip()
end

function M.abort()
  git.revert.abort()
end

return M
