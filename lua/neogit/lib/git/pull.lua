local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

function M.pull_interactive(remote, branch, args)
  local client = require("neogit.client")
  local envs = client.get_envs_git_editor()
  return cli.pull.env(envs).args(remote or "", branch or "").arg_list(args).call_interactive()
end

local function update_unpulled(state)
  if not state.upstream.branch then
    return
  end

  local result = cli.log.oneline.for_range("..@{upstream}").show_popup(false).call():trim().stdout

  state.unpulled.items = util.map(result, function(x)
    return { name = x }
  end)
end

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
