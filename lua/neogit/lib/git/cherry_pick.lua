local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")
local client = require("neogit.client")

---@class NeogitGitCherryPick
local M = {}

local function fire_cherrypick_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitCherryPick", modeline = false, data = data })
end

function M.pick(commits, args)
  local cmd = git.cli["cherry-pick"].arg_list(util.merge(args, commits))

  local result
  if vim.tbl_contains(args, "--edit") then
    result = cmd.env(client.get_envs_git_editor()).call { pty = true }
  else
    result = cmd.call { await = true }
  end

  if result.code ~= 0 then
    notification.error("Cherry Pick failed. Resolve conflicts before continuing")
  else
    fire_cherrypick_event { commits = commits }
  end
end

function M.apply(commits, args)
  args = util.filter_map(args, function(arg)
    if arg ~= "--ff" then
      return arg
    end
  end)

  local result = git.cli["cherry-pick"].no_commit.arg_list(util.merge(args, commits)).call { await = true }
  if result.code ~= 0 then
    notification.error("Cherry Pick failed. Resolve conflicts before continuing")
  else
    fire_cherrypick_event { commits = commits }
  end
end

function M.continue()
  git.cli["cherry-pick"].continue.call { await = true }
end

function M.skip()
  git.cli["cherry-pick"].skip.call { await = true }
end

function M.abort()
  git.cli["cherry-pick"].abort.call { await = true }
end

return M
