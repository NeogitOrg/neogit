local M = {}

local git = require("neogit.lib.git")
local client = require("neogit.client")
local util = require("neogit.lib.util")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

---@param popup any
---@return CommitLogEntry[]
local function get_commits(popup)
  local commits
  if #popup.state.env.commits > 0 then
    commits = util.reverse(popup.state.env.commits)
  else
    commits = CommitSelectViewBuffer.new(
      git.log.list { "--max-count=256" },
      "Select one or more commits to revert with <cr>, or <esc> to abort"
    ):open_async()
  end

  return commits or {}
end

function M.commits(popup)
  local commits = get_commits(popup)
  if #commits == 0 then
    return
  end

  local args = popup:get_arguments()

  local revert_cmd = git.cli.revert.arg_list(util.merge(args, commits))

  client.wrap(revert_cmd, {
    autocmd = "NeogitRevertComplete",
    msg = {
      success = "Reverted",
      fail = "Revert failed. Resolve conflicts before continuing",
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
