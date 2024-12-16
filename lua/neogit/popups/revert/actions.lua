local M = {}

local git = require("neogit.lib.git")
local client = require("neogit.client")
local notification = require("neogit.lib.notification")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

---@param popup any
---@param thing string
---@return string[]
local function get_commits(popup, thing)
  if #popup.state.env.commits > 1 then
    return popup.state.env.commits
  else
    local refs =
      util.merge(popup.state.env.commits, git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())

    return { FuzzyFinderBuffer.new(refs):open_async { prompt_prefix = "Revert " .. thing } }
  end
end

local function build_commit_message(commits)
  local message = {}
  table.insert(message, string.format("Revert %d commits\n", #commits))

  for _, commit in ipairs(commits) do
    table.insert(message, string.format("%s '%s'", commit:sub(1, 7), git.log.message(commit)))
  end

  return table.concat(message, "\n")
end

function M.commits(popup)
  local commits = get_commits(popup, "commits")
  if #commits == 0 then
    return
  end

  local args = popup:get_arguments()
  local success, msg = git.revert.commits(commits, args)
  if not success then
    notification.error("Revert failed with " .. msg)
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
    msg = {
      success = "Reverted",
    },
  })
end

function M.changes(popup)
  local commits = get_commits(popup, "changes")
  if #commits > 0 then
    local success, msg = git.revert.commits(commits, popup:get_arguments())
    if not success then
      notification.error("Revert failed with " .. msg)
    end
  end
end

function M.hunk(popup)
  local hunk = popup.state.env.hunk
  if hunk == nil then
    return
  end
  git.revert.hunk(hunk.hunk, popup:get_arguments())
end

function M.continue()
  git.revert.continue()
end

function M.skip()
  git.revert.skip()
end

function M.abort()
  if input.get_permission("Abort revert?") then
    git.revert.abort()
  end
end

return M
