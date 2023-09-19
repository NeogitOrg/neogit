local client = require("neogit.client")
local notification = require("neogit.lib.notification")
local cli = require("neogit.lib.git.cli")
local branch_lib = require("neogit.lib.git.branch")

local M = {}

local a = require("plenary.async")

local function merge_command(cmd)
  local envs = client.get_envs_git_editor()
  return cmd.env(envs).show_popup(true):in_pty(true).call(true)
end

function M.merge(branch, args)
  a.util.scheduler()
  local result = merge_command(cli.merge.args(branch).arg_list(args))
  if result.code ~= 0 then
    notification.error("Merging failed. Resolve conflicts before continuing")
  else
    notification.info("Merged '" .. branch .. "' into '" .. branch_lib.current() .. "'")
  end
end

function M.continue()
  return merge_command(cli.merge.continue)
end

function M.abort()
  return merge_command(cli.merge.abort)
end

function M.update_merge_status(state)
  if state.git_root == "" then
    return
  end

  state.merge = { head = nil, msg = "", items = {} }

  local merge_head = state.git_path("MERGE_HEAD")
  if not merge_head:exists() then
    return
  end

  state.merge.head = merge_head:read():match("([^\r\n]+)")

  local message = state.git_path("MERGE_MSG")
  if message:exists() then
    state.merge.msg = message:read():match("([^\r\n]+)") -- we need \r? to support windows
  end
end

M.register = function(meta)
  meta.update_merge_status = M.update_merge_status
end

return M
