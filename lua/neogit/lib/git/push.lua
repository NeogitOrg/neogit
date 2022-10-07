local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

function M.push_interactive(remote, branch, args)
  return cli.push.args(remote or "", branch or "").args(args).call_interactive()
end

local function update_unmerged(state)
  if not state.upstream.branch then
    return
  end

  local result = cli.log.oneline.for_range("@{upstream}..").show_popup(false).call():trim().stdout

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
