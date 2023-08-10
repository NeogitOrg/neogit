local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

function M.commits(commits, args)
  return cli.revert.no_commit.arg_list(util.merge(args, commits)).call().code == 0
end

function M.continue()
  cli.revert.continue.call_sync()
end

function M.skip()
  cli.revert.skip.call_sync()
end

function M.abort()
  cli.revert.abort.call_sync()
end

return M
