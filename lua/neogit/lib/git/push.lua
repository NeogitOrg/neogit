local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local log_cache = require("neogit.lib.git.log_cache")

---@class NeogitGitPush
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

---Pushes to the remote and handles password questions
---@param remote string?
---@param branch string?
---@param args string[]
---@return ProcessResult
function M.push_interactive(remote, branch, args)
  return git.cli.push.args(remote or "", branch or "").arg_list(args).call { pty = true }
end

---@param branch string|nil
---@return boolean
function M.auto_setup_remote(branch)
  if not branch then
    return false
  end

  local push_autoSetupRemote = git.config.get("push.autoSetupRemote"):read()
  local push_default = git.config.get("push.default"):read()
  local branch_remote = git.config.get_local("branch." .. branch .. ".remote"):read()

  return (
    push_autoSetupRemote
    and (push_default == "current" or push_default == "simple" or push_default == "upstream")
    and not branch_remote
  ) == true
end

local function update_unmerged(state)
  local status = git.branch.status()

  state.upstream.unmerged.items = {}
  state.pushRemote.unmerged.items = {}

  if status.detached then
    return
  end

  if status.upstream and has_commits_in_range("@{upstream}..") then
    state.upstream.unmerged.items = util.filter_map(get_log_cached("@{upstream}.."), git.log.present_commit_fast)
  end

  local pushRemote = require("neogit.lib.git").branch.pushRemote_ref()
  if pushRemote and pushRemote ~= status.upstream and has_commits_in_range(pushRemote .. "..") then
    state.pushRemote.unmerged.items = util.filter_map(get_log_cached(pushRemote .. ".."), git.log.present_commit_fast)
  elseif pushRemote and pushRemote == status.upstream then
    -- Reuse upstream results when pushRemote is the same ref
    state.pushRemote.unmerged.items = state.upstream.unmerged.items
  end
end

function M.register(meta)
  meta.update_unmerged = update_unmerged
end

return M
