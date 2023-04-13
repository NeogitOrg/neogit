local logger = require("neogit.logger")
local client = require("neogit.client")
local notif = require("neogit.lib.notification")

local M = {}

local a = require("plenary.async")

local function merge_command(cmd)
  local git = require("neogit.lib.git")
  cmd = cmd or git.cli.rebase
  local envs = client.get_envs_git_editor()
  return cmd.env(envs).show_popup(true):in_pty(true).call(true)
end

function M.rebase_interactive(...)
  a.util.scheduler()
  local git = require("neogit.lib.git")
  local result = merge_command(git.cli.merge.interactive.args(...))
  if result.code ~= 0 then
    notif.create("Rebasing failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
  end
  a.util.scheduler()
  local status = require("neogit.status")
  status.refresh(true, "rebase_interactive")
end

function M.merge(branch, args)
  a.util.scheduler()
  local git = require("neogit.lib.git")
  local result = merge_command(git.cli.merge.args(branch).arg_list(args))
  if result.code ~= 0 then
    notif.create("Rebasing failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
  end
end

function M.continue()
  local git = require("neogit.lib.git")
  return merge_command(git.cli.merge.continue)
end

function M.abort()
  local git = require("neogit.lib.git")
  return merge_command(git.cli.merge.abort)
end

local uv = require("neogit.lib.uv")
function M.update_merge_status(state)
  local cli = require("neogit.lib.git.cli")
  local root = cli.git_root()
  if root == "" then
    return
  end

  local merge = {
    items = {},
    head = nil,
    msg = "",
  }

  local mfile = root .. "/.git/MERGE_HEAD"
  local _, stat = a.uv.fs_stat(mfile)

  -- Find the rebase progress files

  if not stat then
    return
  end

  local err, head = uv.read_file(mfile)
  if not head then
    logger.error("Failed to read merge head: " .. err)
    return
  end
  head = head:match("([^\r\n]+)")
  merge.head = head

  local _, msg = uv.read_file(root .. "/.git/MERGE_MSG")

  -- we need \r? to support windows
  if msg then
    merge.msg = msg:match("([^\r\n]+)")
  end

  state.merge = merge
end

M.register = function(meta)
  meta.update_merge_status = M.update_merge_status
end

return M
