local cli = require("neogit.lib.git.cli")

local M = {}

---Fetches from the remote and handles password questions
---@param remote string
---@param branch string
---@param args string[]
---@return ProcessResult
function M.fetch_interactive(remote, branch, args)
  return cli.fetch.args(remote or "", branch or "").arg_list(args).call_interactive()
end

function M.fetch_upstream()
  local repo = require("neogit.lib.git").repo
  if repo.upstream.branch and repo.upstream.remote then
    cli.fetch.args(repo.upstream.remote, repo.upstream.branch).call_ignoring_exit_code()
  end
end

function M.fetch_pushRemote()
  local branch = require("neogit.lib.git.branch")
  if not branch.pushRemote_ref() then
    return
  end

  local remote, branch = branch.pushRemote_ref():match("^([^/]*)/(.*)$")
  cli.fetch.args(remote, branch).call_ignoring_exit_code()
end

return M
