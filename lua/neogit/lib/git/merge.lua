local client = require("neogit.client")
local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")

---@class NeogitGitMerge
local M = {}

local function merge_command(cmd)
  return cmd.env(client.get_envs_git_editor()).call { pty = true }
end

local function fire_merge_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitMerge", modeline = false, data = data })
end

function M.merge(branch, args)
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

---@return boolean
function M.in_progress()
  return git.repo.state.merge.head ~= nil
end

---@param path string filepath to check for conflict markers
---@return boolean
function M.is_conflicted(path)
  return git.cli.diff.check.files(path).call().code ~= 0
end

---@return boolean
function M.any_conflicted()
  return git.cli.diff.check.call().code ~= 0
end

---@class MergeItem
---Not used, just for a consistent interface

M.register = function(meta)
  meta.update_merge_status = function(state)
    state.merge = { head = nil, branch = nil, msg = "", items = {} }

    local merge_head = git.repo:worktree_git_path("MERGE_HEAD")
    if not merge_head:exists() then
      return
    end

    state.merge.head = merge_head:read():match("([^\r\n]+)")
    state.merge.subject = git.log.message(state.merge.head)

    local message = git.repo:worktree_git_path("MERGE_MSG")
    if message:exists() then
      state.merge.msg = message:read():match("([^\r\n]+)") -- we need \r? to support windows
      state.merge.branch = state.merge.msg:match("Merge branch '(.*)'$")
    end
  end
end

return M
