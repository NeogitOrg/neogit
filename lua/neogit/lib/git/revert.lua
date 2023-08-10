local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")
local util = require("neogit.lib.util")

local M = {}

function M.commits(commits, args)
  local result = cli.revert.no_commit.arg_list(util.merge(args, commits)).call()
  if result.code ~= 0 then
    notif.create("Revert failed", vim.log.levels.ERROR)
    return false
  end
  return true
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
