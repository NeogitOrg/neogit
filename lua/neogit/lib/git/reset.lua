local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")
local a = require("plenary.async")

local M = {}

function M.mixed(commit)
  a.util.scheduler()

  local result = cli.reset.mixed.args(commit).call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  else
    notif.create("Reset to " .. commit, vim.log.levels.INFO)
  end
end

function M.soft(commit)
  a.util.scheduler()

  local result = cli.reset.soft.args(commit).call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  else
    notif.create("Reset to " .. commit, vim.log.levels.INFO)
  end
end

function M.hard(commit)
  a.util.scheduler()

  local result = cli.reset.hard.args(commit).call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  else
    notif.create("Reset to " .. commit, vim.log.levels.INFO)
  end
end

function M.keep(commit)
  a.util.scheduler()

  local result = cli.reset.keep.args(commit).call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  else
    notif.create("Reset to " .. commit, vim.log.levels.INFO)
  end
end

function M.index(commit)
  a.util.scheduler()

  local result = cli.reset.args(commit).files(".").call()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  else
    notif.create("Reset to " .. commit, vim.log.levels.INFO)
  end
end

-- TODO: Worktree support
--   "Reset the worktree to COMMIT. Keep the `HEAD' and index as-is."
--
--   (magit-wip-commit-before-change nil " before reset")
--   (magit-with-temp-index commit nil (magit-call-git "checkout-index" "--all" "--force"))
--   (magit-wip-commit-after-apply nil " after reset")
--
-- function M.worktree(commit)
-- end

function M.file(commit, files)
  local result = cli.checkout.rev(commit).files(unpack(files)).call_sync()
  if result.code ~= 0 then
    notif.create("Reset Failed", vim.log.levels.ERROR)
  else
    if #files > 1 then
      notif.create("Reset " .. #files .. " files", vim.log.levels.info)
    else
      notif.create("Reset " .. files[1], vim.log.levels.info)
    end
  end
end

return M
