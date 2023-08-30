local M = {}

local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

local LogViewBuffer = require("neogit.buffers.log_view")
local ReflogViewBuffer = require("neogit.buffers.reflog_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

---Builds a graph for the popup if required
---@param popup table
---@return table|nil
local function maybe_graph(popup)
  local args = popup:get_internal_arguments()
  if args.graph then
    local external_args = popup:get_arguments()
    util.remove_item_from_table(external_args, "--show-signature")
    return git.log.graph(external_args)
  end
end

--- Runs `git log` and parses the commits
---@param popup table Contains the argument list
---@param extras table|nil
---@return CommitLogEntry[]
local function commits(popup, extras)
  return git.log.list(util.merge(popup:get_arguments(), extras or {}), maybe_graph(popup))
end

-- TODO: Handle when head is detached
function M.log_current(popup)
  LogViewBuffer.new(commits(popup), popup:get_internal_arguments()):open()
end

function M.log_head(popup)
  LogViewBuffer.new(commits(popup, { "HEAD" }), popup:get_internal_arguments()):open()
end

function M.log_local_branches(popup)
  LogViewBuffer.new(
    commits(popup, { git.branch.is_detached() and "" or "HEAD", "--branches" }),
    popup:get_internal_arguments()
  ):open()
end

function M.log_other(popup)
  local branch = FuzzyFinderBuffer.new(git.branch.get_local_branches()):open_async()
  if branch then
    LogViewBuffer.new(commits(popup, { branch }), popup:get_internal_arguments()):open()
  end
end

function M.log_all_branches(popup)
  LogViewBuffer.new(
    commits(popup, { git.branch.is_detached() and "" or "HEAD", "--branches", "--remotes" }),
    popup:get_internal_arguments()
  ):open()
end

function M.log_all_references(popup)
  LogViewBuffer.new(
    commits(popup, { git.branch.is_detached() and "" or "HEAD", "--all" }),
    popup:get_internal_arguments()
  )
    :open()
end

function M.reflog_current(popup)
  ReflogViewBuffer.new(git.reflog.list(git.branch.current(), popup:get_arguments())):open()
end

function M.reflog_head(popup)
  ReflogViewBuffer.new(git.reflog.list("HEAD", popup:get_arguments())):open()
end

function M.reflog_other(popup)
  local branch = FuzzyFinderBuffer.new(git.branch.get_local_branches()):open_async()
  if branch then
    ReflogViewBuffer.new(git.reflog.list(branch, popup:get_arguments())):open()
  end
end

return M
