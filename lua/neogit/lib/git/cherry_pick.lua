local cli = require("neogit.lib.git.cli")
local logger = require("neogit.logger")
local notif = require("neogit.lib.notification")
local util = require("neogit.lib.util")

local M = {}

local a = require("plenary.async")

function M.pick(commits, args)
  a.util.scheduler()

  local result = cli["cherry-pick"].arg_list({ unpack(args), unpack(commits) }).call()
  if result.code ~= 0 then
    notif.create("Cherry Pick failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
  end
end

function M.apply(commits, args)
  a.util.scheduler()

  local result = cli["cherry-pick"].no_commit.arg_list(util.merge(args, commits)).call()
  if result.code ~= 0 then
    notif.create("Cherry Pick failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
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
