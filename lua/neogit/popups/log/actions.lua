local M = {}

local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

local LogViewBuffer = require("neogit.buffers.log_view")
local ReflogViewBuffer = require("neogit.buffers.reflog_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

function M.log_current(popup)
  LogViewBuffer.new(git.log.list(popup:get_arguments()), popup:get_internal_arguments()):open()
end

function M.log_head(popup)
  LogViewBuffer.new(
    git.log.list(util.merge(popup:get_arguments(), { "HEAD" })),
    popup:get_internal_arguments()
  )
    :open()
end

function M.log_local_branches(popup)
  LogViewBuffer.new(
    git.log.list(util.merge(popup:get_arguments(), {
      git.repo.head.branch and "" or "HEAD",
      "--branches",
    })),
    popup:get_internal_arguments()
  ):open()
end

function M.log_all_branches(popup)
  LogViewBuffer.new(
    git.log.list(util.merge(popup:get_arguments(), {
      git.repo.head.branch and "" or "HEAD",
      "--branches",
      "--remotes",
    })),
    popup:get_internal_arguments()
  ):open()
end

function M.log_all_references(popup)
  LogViewBuffer.new(
    git.log.list(util.merge(popup:get_arguments(), {
      git.repo.head.branch and "" or "HEAD",
      "--all",
    })),
    popup:get_internal_arguments()
  ):open()
end

function M.reflog_current(popup)
  ReflogViewBuffer.new(git.reflog.list(git.repo.head.branch, popup:get_arguments())):open()
end

function M.reflog_head(popup)
  ReflogViewBuffer.new(git.reflog.list("HEAD", popup:get_arguments())):open()
end

function M.reflog_other(popup)
  local branch = FuzzyFinderBuffer.new(git.branch.get_local_branches()):open_sync()
  if branch then
    ReflogViewBuffer.new(git.reflog.list(branch, popup:get_arguments())):open()
  end
end

return M
