local client = require("neogit.client")
local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")

local a = require("plenary.async")

---@class NeogitGitMerge
local M = {}

local function merge_command(cmd)
  local envs = client.get_envs_git_editor()
  return cmd.env(envs).show_popup(true):in_pty(true).call { verbose = true }
end

local function fire_merge_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitMerge", modeline = false, data = data })
end

function M.merge(branch, args)
  a.util.scheduler()
  local result = merge_command(git.cli.merge.args(branch).arg_list(args))
  if result.code ~= 0 then
    notification.error("Merging failed. Resolve conflicts before continuing")
    fire_merge_event { branch = branch, args = args, status = "conflict" }
  else
    notification.info("Merged '" .. branch .. "' into '" .. git.branch.current() .. "'")
    fire_merge_event { branch = branch, args = args, status = "ok" }
  end
end

function M.continue()
  return merge_command(git.cli.merge.continue)
end

function M.abort()
  return merge_command(git.cli.merge.abort)
end

---@class MergeItem
---Not used, just for a consistent interface

M.register = function(meta)
  meta.update_merge_status = function(state)
    state.merge = { head = nil, branch = nil, msg = "", items = {} }

    local merge_head = git.repo:git_path("MERGE_HEAD")
    if not merge_head:exists() then
      return
    end

    state.merge.head = merge_head:read():match("([^\r\n]+)")
    state.merge.subject = git.log.message(state.merge.head)

    local message = git.repo:git_path("MERGE_MSG")
    if message:exists() then
      state.merge.msg = message:read():match("([^\r\n]+)") -- we need \r? to support windows
      state.merge.branch = state.merge.msg:match("Merge branch '(.*)'$")
    end
  end
end

return M
