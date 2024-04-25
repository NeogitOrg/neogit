local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

---@class NeogitGitRevert
local M = {}

function M.commits(commits, args)
  return git.cli.revert.no_commit.arg_list(util.merge(args, commits)).call().code == 0
end

function M.continue()
  git.cli.revert.continue.call_sync()
end

function M.skip()
  git.cli.revert.skip.call_sync()
end

function M.abort()
  git.cli.revert.abort.call_sync()
end

return M
