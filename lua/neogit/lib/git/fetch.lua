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

return M
