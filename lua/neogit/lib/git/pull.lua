local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

-- TODO: client.wrap()
function M.pull_interactive(remote, branch, args)
  local client = require("neogit.client")
  local envs = client.get_envs_git_editor()
  return cli.pull.env(envs).args(remote or "", branch or "").arg_list(args).call_interactive()
end

local function update_unpulled(state)
  if state.upstream.ref then
    local result = cli.log.oneline.for_range("..@{upstream}").show_popup(false).call():trim().stdout

    state.upstream.unpulled = { items = {} }
    state.upstream.unpulled.items = util.map(result, function(x)
      return { name = x }
    end)
  end

  local pushRemote = require("neogit.lib.git").branch.pushRemote_ref()
  if pushRemote then
    local result = cli.log.oneline.for_range(".." .. pushRemote).show_popup(false).call_sync():trim().stdout

    state.pushRemote.unpulled = { items = {} }
    state.pushRemote.unpulled.items = util.map(result, function(x)
      return { name = x }
    end)
  end
end

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
