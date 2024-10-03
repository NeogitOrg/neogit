local git = require("neogit.lib.git")

---@class NeogitGitFetch
local M = {}

---Fetches from the remote and handles password questions
---@param remote string
---@param branch string
---@param args string[]
---@return ProcessResult
function M.fetch_interactive(remote, branch, args)
  return git.cli.fetch.args(remote or "", branch or "").arg_list(args).call { pty = true }
end

---@param remote string
---@param branch string
---@return ProcessResult
function M.fetch(remote, branch)
  return git.cli.fetch.args(remote, branch).call { ignore_error = true }
end

return M
