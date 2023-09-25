local cli = require("neogit.lib.git.cli")
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")

local M = {}

function M.pick(commits, args)
  local result = cli["cherry-pick"].arg_list(util.merge(args, commits)).call()
  if result.code ~= 0 then
    notification.error("Cherry Pick failed. Resolve conflicts before continuing")
  end
end

function M.apply(commits, args)
  args = util.filter_map(args, function(arg)
    if arg ~= "--ff" then
      return arg
    end
  end)

  local result = cli["cherry-pick"].no_commit.arg_list(util.merge(args, commits)).call()
  if result.code ~= 0 then
    notification.error("Cherry Pick failed. Resolve conflicts before continuing")
  end
end

function M.continue()
  cli["cherry-pick"].continue.call_sync()
end

function M.skip()
  cli["cherry-pick"].skip.call_sync()
end

function M.abort()
  cli["cherry-pick"].abort.call_sync()
end

return M
