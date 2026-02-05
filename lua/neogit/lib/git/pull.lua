local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local log_cache = require("neogit.lib.git.log_cache")

---@class NeogitGitPull
local M = {}

--- Fast check if a commit range has any commits (avoids expensive git log formatting)
---@param range string Git revision range (e.g., "@{upstream}.." or "..@{upstream}")
---@return boolean
local function has_commits_in_range(range)
  local result = git.cli["rev-list"].args("--count", range).call({ hidden = true, ignore_error = true })
  if result:success() then
    local count = tonumber(result.stdout[1])
    return count and count > 0
  end
  return false
end

--- Get log results with OID-based caching
---@param range string Git revision range
---@return CommitLogEntry[]
local function get_log_cached(range)
  local cached = log_cache.get(range)
  if cached then
    return cached
  end

  local result = git.log.list({ range }, nil, {}, true)
  log_cache.set(range, result)
  return result
end

function M.pull_interactive(remote, branch, args)
  local client = require("neogit.client")
  local envs = client.get_envs_git_editor()
  return git.cli.pull.env(envs).args(remote or "", branch or "").arg_list(args).call { pty = true }
end

local function update_unpulled(state)
  local status = git.branch.status()

  state.upstream.unpulled.items = {}
  state.pushRemote.unpulled.items = {}

  if status.detached then
    return
  end

  if status.upstream and has_commits_in_range("..@{upstream}") then
    state.upstream.unpulled.items = util.filter_map(get_log_cached("..@{upstream}"), git.log.present_commit_fast)
  end

  local pushRemote = git.branch.pushRemote_ref()
  local pushRemoteRange = pushRemote and string.format("..%s", pushRemote)
  if pushRemote and pushRemote ~= status.upstream and has_commits_in_range(pushRemoteRange) then
    state.pushRemote.unpulled.items = util.filter_map(get_log_cached(pushRemoteRange), git.log.present_commit_fast)
  elseif pushRemote and pushRemote == status.upstream then
    -- Reuse upstream results when pushRemote is the same ref
    state.pushRemote.unpulled.items = state.upstream.unpulled.items
  end
end

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
