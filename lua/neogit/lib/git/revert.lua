local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

---@class NeogitGitRevert
local M = {}

function M.commits(commits, args)
  return git.cli.revert.no_commit.arg_list(util.merge(args, commits)).call({ pty = true }).code == 0
end

function M.hunk(hunk, _)
  local patch = git.index.generate_patch(hunk, { reverse = true })
  git.index.apply(patch, { reverse = true })
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
