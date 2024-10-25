local notification = require("neogit.lib.notification")
local git = require("neogit.lib.git")

---@class NeogitGitReset
local M = {}

local function fire_reset_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitReset", modeline = false, data = data })
end

function M.mixed(commit)
  local result = git.cli.reset.mixed.args(commit).call { await = true }
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "mixed" }
  end
end

function M.soft(commit)
  local result = git.cli.reset.soft.args(commit).call { await = true }
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "soft" }
  end
end

function M.hard(commit)
  git.index.create_backup()

  local result = git.cli.reset.hard.args(commit).call { await = true }
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "hard" }
  end
end

function M.keep(commit)
  local result = git.cli.reset.keep.args(commit).call { await = true }
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    notification.info("Reset to " .. commit)
    fire_reset_event { commit = commit, mode = "keep" }
  end
end

function M.index(commit)
  local result = git.cli.reset.args(commit).files(".").call { await = true }
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
  local result = git.cli.checkout.rev(commit).files(unpack(files)).call { await = true }
  if result.code ~= 0 then
    notification.error("Reset Failed")
  else
    fire_reset_event { commit = commit, mode = "files" }
    if #files > 1 then
      notification.info("Reset " .. #files .. " files")
    else
      notification.info("Reset " .. files[1])
    end
  end
end

return M
