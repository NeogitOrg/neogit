local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

---@class NeogitGitRevert
local M = {}

---@param commits string[]
---@param args string[]
---@return boolean, string|nil
function M.commits(commits, args)
  local result = git.cli.revert.no_commit.arg_list(util.merge(args, commits)).call { pty = true }
  if result.code == 0 then
    return true, ""
  else
    return false, result.stdout[1]
  end
end

function M.hunk(hunk, _)
  local patch = git.index.generate_patch(hunk, { reverse = true })
  git.index.apply(patch, { reverse = true })
end

function M.continue()
  git.cli.revert.continue.no_edit.call { pty = true }
end

function M.skip()
  git.cli.revert.skip.call()
end

function M.abort()
  git.cli.revert.abort.call()
end

return M
