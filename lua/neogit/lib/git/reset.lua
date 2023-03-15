local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")
local a = require("plenary.async")

local M = {}

function M.mixed(commit)
  a.util.scheduler()

  local result = cli.reset.mixed.args(commit).call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  end
end

function M.soft(commit)
  a.util.scheduler()

  local result = cli.reset.soft.args(commit).call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  end
end

function M.hard(commit)
  a.util.scheduler()

  local result = cli.reset.hard.args(commit).call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  end
end

function M.keep(commit)
  a.util.scheduler()

  local result = cli.reset.keep.args(commit).call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  end
end

-- function M.index(commit)
--   a.util.scheduler()
--
--   local result = cli.reset.hard.args(commit).call()
--   if result.code ~= 0 then
--     notif.create("Reset Failed", vim.log.levels.ERROR)
--   end
-- end

-- function M.worktree(commit)
--   a.util.scheduler()
--
--   local result = cli.reset.hard.args(commit).call()
--   if result.code ~= 0 then
--     notif.create("Reset Failed", vim.log.levels.ERROR)
--   end
-- end

function M.file(commit, file)
  local result = cli.checkout.rev(commit).files(file).call_sync()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  end
end

return M
