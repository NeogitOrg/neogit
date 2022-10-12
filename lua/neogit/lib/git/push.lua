local cli = require("neogit.lib.git.cli")
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
  print("update_unmerged")
  if not state.upstream.branch then
    return
  end

  print("Looking for unmerged with upstream: ", state.upstream.branch)
  local result = cli.log.oneline.for_range("@{upstream}..").show_popup(false).call():trim().stdout
  print("Got: ", vim.inspect(result))

  state.unmerged.items = util.filter_map(result, function(x)
    if x == "" then
      return
    end
    return { name = x }
  end)
end

function M.register(meta)
  meta.update_unmerged = update_unmerged
end

return M
