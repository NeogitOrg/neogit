local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

function M.pull_interactive(remote, branch, args)
  return cli.pull.args(remote or "", branch or "").args(args).call_interactive()
end

local function update_unpulled(state)
  if not state.upstream.branch then
    return
  end

  local result = cli.log.oneline.for_range("..@{upstream}").show_popup(false).call()

  state.unpulled.items = util.filter_map(result, function(x)
    if x == "" then
      return
    end
    return { name = x }
  end)
end

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
