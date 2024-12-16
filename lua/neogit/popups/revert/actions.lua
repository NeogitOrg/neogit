local M = {}

local config = require("neogit.config")
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

  local commit_cmd = git.cli.commit.no_verify
  if vim.tbl_contains(args, "--edit") then
    commit_cmd = commit_cmd.edit
  else
    commit_cmd = commit_cmd.no_edit
  end

  client.wrap(commit_cmd, {
    autocmd = "NeogitRevertComplete",
    interactive = true,
    msg = {
      success = "Reverted",
    },
    show_diff = config.values.commit_editor.show_staged_diff,
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
  local item = popup.state.env.item
  if item == nil then
    return
  end
  git.revert.hunk(item.hunk, popup:get_arguments())
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
