local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

---@class NeogitGitPull
local M = {}

function M.pull_interactive(remote, branch, args)
  local client = require("neogit.client")
  local envs = client.get_envs_git_editor()
  return git.cli.pull.env(envs).args(remote or "", branch or "").arg_list(args).call_interactive()
end

local function update_unpulled(state)
  state.upstream.unpulled.items = {}
  state.pushRemote.unpulled.items = {}

  if state.head.branch == "(detached)" then
    return
  end

  if state.upstream.ref then
    state.upstream.unpulled.items =
      util.filter_map(git.log.list({ "..@{upstream}" }, nil, {}, true), git.log.present_commit)
  end

  local pushRemote = require("neogit.lib.git").branch.pushRemote_ref()
  if pushRemote then
    state.pushRemote.unpulled.items = util.filter_map(
      git.log.list({ string.format("..%s", pushRemote) }, nil, {}, true),
      git.log.present_commit
    )
  end
end

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
