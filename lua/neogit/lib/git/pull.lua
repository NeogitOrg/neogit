local cli = require("neogit.lib.git.cli")

local M = {}

function M.pull_interactive(remote, branch, args)
  local client = require("neogit.client")
  local envs = client.get_envs_git_editor()
  return cli.pull.env(envs).args(remote or "", branch or "").arg_list(args).call_interactive()
end

local function update_unpulled(state)
  local upstream_unpulled = {}
  local pushRemote_unpulled = {}

  if state.upstream.ref then
    local result = cli.log.oneline.for_range("..@{upstream}").show_popup(false).call():trim().stdout

    for _, name in ipairs(result) do
      table.insert(upstream_unpulled, { name = name })
    end
  end

  local pushRemote = require("neogit.lib.git").branch.pushRemote_ref()
  if pushRemote then
    local result = cli.log.oneline.for_range(".." .. pushRemote).show_popup(false).call():trim().stdout

    for _, name in ipairs(result) do
      table.insert(pushRemote_unpulled, { name = name })
    end
  end

  state.upstream.unpulled.items = upstream_unpulled
  state.pushRemote.unpulled.items = pushRemote_unpulled
end

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
