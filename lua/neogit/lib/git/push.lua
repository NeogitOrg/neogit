local cli = require("neogit.lib.git.cli")
local log = require("neogit.lib.git.log")
local util = require("neogit.lib.util")

local M = {}

---Pushes to the remote and handles password questions
---@param remote string
---@param branch string
---@param args string[]
---@return ProcessResult
function M.push_interactive(remote, branch, args)
  return cli.push.args(remote or "", branch or "").arg_list(args).call_interactive()
end

local function update_unmerged(state)
  state.upstream.unmerged.items = {}
  state.pushRemote.unmerged.items = {}

  if state.head.branch == "(detached)" then
    return
  end

  if state.upstream.ref then
    state.upstream.unmerged.items = util.filter_map(log.list { "@{upstream}.." }, log.present_commit)
  end

  local pushRemote = require("neogit.lib.git").branch.pushRemote_ref()
  if pushRemote then
    state.pushRemote.unmerged.items = util.filter_map(log.list { pushRemote .. ".." }, log.present_commit)
  end
end

function M.register(meta)
  meta.update_unmerged = update_unmerged
end

return M
