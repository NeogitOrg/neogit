local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")
local a = require("plenary.async")

local M = {}

local function do_revert(cmd)
  a.util.scheduler()

  local notification = notif.create("Reverting...", vim.log.levels.INFO, 9999)

  local client = require("neogit.client")
  local envs = client.get_envs_git_editor()

  local result = cmd.env(envs):in_pty(true).call(true):trim()

  a.util.scheduler()
  if notification then
    notification:delete()
  end

  if result.code == 0 then
    notif.create("Successfully reverted!")
    vim.api.nvim_exec_autocmds("User", { pattern = "NeogitRevertComplete", modeline = false })
  end

  a.util.scheduler()

  require("neogit.status").refresh(true, "do_revert")
end

-- TODO: Add proper support for multiple commits
function M.commits(commits, args)
  do_revert(cli.revert.args(table.concat(commits, " ")).arg_list(args))
end

return M
