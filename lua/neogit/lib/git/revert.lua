local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

---@class NeogitGitRevert
local M = {}

function M.commits(commits, args)
  return git.cli.revert.no_commit.arg_list(util.merge(args, commits)).call({ await = true }).code == 0
end

function M.continue()
  git.cli.revert.continue.call()
end

function M.skip()
  git.cli.revert.skip.call()
end

function M.abort()
  git.cli.revert.abort.call()
end

return M
