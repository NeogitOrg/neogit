local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

local function condense_commits(commits)
  if #commits > 1 then
    local first = commits[1]
    local last = commits[#commits]
    commits = { string.format("%s~1..%s", first, last) }
  end

  return commits
end

function M.commits(commits, args)
  return cli.revert.no_commit.arg_list(util.merge(args, condense_commits(commits))).call().code == 0
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
