local M = {}

local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

local LogViewBuffer = require("neogit.buffers.log_view")
local ReflogViewBuffer = require("neogit.buffers.reflog_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

function M.log_current(popup)
  local args = popup:get_internal_arguments()
  local commits = git.log.list(popup:get_arguments(), args)

  LogViewBuffer.new(commits, args):open()
end

function M.log_head(popup)
  local args = popup:get_internal_arguments()
  local commits = git.log.list(util.merge(popup:get_arguments(), { "HEAD" }), args)

  LogViewBuffer.new(commits, args):open()
end

function M.log_local_branches(popup)
  local args = popup:get_internal_arguments()
  local commits = git.log.list(
    util.merge(popup:get_arguments(), { git.branch.is_detached() and "" or "HEAD", "--branches" }),
    args
  )

  LogViewBuffer.new(commits, args):open()
end

function M.log_other(popup)
  local args = popup:get_internal_arguments()
  local branch = FuzzyFinderBuffer.new(git.branch.get_local_branches()):open_async()
  if branch then
    local commits = git.log.list(util.merge(popup:get_arguments(), { branch }), args)

    LogViewBuffer.new(commits, args):open()
  end
end

function M.log_all_branches(popup)
  local args = popup:get_internal_arguments()
  local commits = git.log.list(
    util.merge(
      popup:get_arguments(),
      { git.branch.is_detached() and "" or "HEAD", "--branches", "--remotes" }
    ),
    args
  )

  LogViewBuffer.new(commits, args):open()
end

function M.log_all_references(popup)
  local args = popup:get_internal_arguments()
  local commits = git.log.list(
    util.merge(popup:get_arguments(), { git.branch.is_detached() and "" or "HEAD", "--all" }),
    args
  )

  LogViewBuffer.new(commits, args):open()
end

function M.reflog_current(popup)
  ReflogViewBuffer.new(git.reflog.list(git.branch.is_detached(), popup:get_arguments())):open()
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
