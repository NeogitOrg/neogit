local git = require("neogit.lib.git")
local lock = require("neogit.lib.git.lock")

---@class NeogitGitFetch
local M = {}

---Fetches from the remote and handles password questions
---@param remote string
---@param branch string
---@param args string[]
---@return ProcessResult
function M.fetch_interactive(remote, branch, args)
  local permit = lock.fetch_pull:acquire()
  local result = git.cli.fetch.args(remote or "", branch or "").arg_list(args).call { pty = true }
  permit:forget()

  return result
end

---@param remote string
---@param branch string
---@return ProcessResult
function M.fetch(remote, branch)
  local permit = lock.fetch_pull:acquire()
  local result = git.cli.fetch.args(remote, branch).call { ignore_error = true }
  permit:forget()

  return result
end

return M
