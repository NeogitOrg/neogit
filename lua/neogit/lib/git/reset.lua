local cli = require("neogit.lib.git.cli")
local notification = require("neogit.lib.notification")
local a = require("plenary.async")

local M = {}

local function fire_reset_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitReset", modeline = false, data = data })
end

function M.mixed(commit)
  a.util.scheduler()

  local result = cli.reset.mixed.args(commit).call()
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "mixed" }
  end
end

function M.soft(commit)
  a.util.scheduler()

  local result = cli.reset.soft.args(commit).call()
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "soft" }
  end
end

function M.hard(commit)
  a.util.scheduler()

  local result = cli.reset.hard.args(commit).call()
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "hard" }
  end
end

function M.keep(commit)
  a.util.scheduler()

  local result = cli.reset.keep.args(commit).call()
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "keep" }
  end
end

function M.index(commit)
  a.util.scheduler()

  local result = cli.reset.args(commit).files(".").call()
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "index" }
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
    notification.error("Reset Failed")
  else
    if #files > 1 then
      notification.info("Reset " .. #files .. " files")
    else
      notification.info("Reset " .. files[1])
    end
  end
end

return M
