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

local a = require("plenary.async")
local notification = require("neogit.lib.notification")

---@param remote string
---@param branch string
function M.fetch(remote, branch)
  notification.info("Fetching...")
  a.void(function()
    local result = git.cli.fetch.args(remote, branch).call { ignore_error = true }

    if result and result.code == 0 then
      notification.info("Fetch complete.")
    elseif result then
      local error_message = "Fetch failed: "
      if type(result.stderr) == "table" then
        error_message = error_message .. table.concat(result.stderr, "\n")
      elseif type(result.stderr) == "string" then
        error_message = error_message .. result.stderr
      else
        error_message = error_message .. "Unknown error format."
      end
      notification.error(error_message)
    else
      notification.error("Fetch failed: An unexpected error occurred and no result was returned.")
    end
  end)()
end

return M
