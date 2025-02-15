local git = require("neogit.lib.git")
local config = require("neogit.config")
local util = require("neogit.lib.util")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

---@class NeogitGitBranch
local M = {}

---@param branches string[]
---@param include_current? boolean
---@return string[]
local function parse_branches(branches, include_current)
  include_current = include_current or false
  local other_branches = {}

  local remotes = "^remotes/(.*)"
  local head = "^(.*)/HEAD"
  local ref = " %-> "
  local detached = "^%(HEAD detached at %x%x%x%x%x%x%x"
  local no_branch = "^%(no branch,"
  local pattern = include_current and "^[* ] (.+)" or "^  (.+)"

  for _, b in ipairs(branches) do
    local branch_name = b:match(pattern)
    if branch_name then
      local name = branch_name:match(remotes) or branch_name
      if
        name
        and not name:match(ref)
        and not name:match(head)
        and not name:match(detached)
        and not name:match(no_branch)
      then
        table.insert(other_branches, name)
      end
    end
  end

  return other_branches
end

---@return string[]
function M.get_recent_local_branches()
  local valid_branches = M.get_local_branches()

  local branches = util.filter_map(
    git.cli.reflog.show.format("%gs").date("relative").call({ hidden = true }).stdout,
    function(ref)
      local name = ref:match("^checkout: moving from .* to (.*)$")
      if vim.tbl_contains(valid_branches, name) then
        return name
      end
    end
  )

  return util.deduplicate(branches)
end

---@param relation? string
---@param commit? string
---@param ... any
---@return string[]
function M.list_related_branches(relation, commit, ...)
  local result = git.cli.branch.args(relation or "", commit or "", ...).call { hidden = true }

  local branches = {}
  for _, branch in ipairs(result.stdout) do
    branch = branch:match("^%s*(.-)%s*$")
    if branch and not branch:match("^%(HEAD") and not branch:match("^HEAD ->") and branch ~= "" then
      table.insert(branches, branch)
    end
  end

  return branches
end

---@param commit string
---@return string[]
function M.list_containing_branches(commit, ...)
  return M.list_related_branches("--contains", commit, ...)
end

---@param name string
---@param args? string[]
---@return ProcessResult
function M.checkout(name, args)
  return git.cli.checkout.branch(name).arg_list(args or {}).call { await = true }
end

---@param name string
---@param args? string[]
function M.track(name, args)
  git.cli.checkout.track(name).arg_list(args or {}).call { await = true }
end

---@param include_current? boolean
---@return string[]
function M.get_local_branches(include_current)
  local branches = git.cli.branch.sort(config.values.sort_branches).call({ hidden = true }).stdout
  return parse_branches(branches, include_current)
end

---@param include_current? boolean
---@return string[]
function M.get_remote_branches(include_current)
  local branches = git.cli.branch.remotes.sort(config.values.sort_branches).call({ hidden = true }).stdout
  return parse_branches(branches, include_current)
end

---@param include_current? boolean
---@return string[]
function M.get_all_branches(include_current)
  return util.merge(M.get_local_branches(include_current), M.get_remote_branches(include_current))
end

---@param branch string
---@param base? string
---@return boolean
function M.is_unmerged(branch, base)
  return git.cli.cherry.arg_list({ base or M.base_branch(), branch }).call({ hidden = true }).stdout[1] ~= nil
end

---@return string|nil
function M.base_branch()
  local value = git.config.get("neogit.baseBranch")
  if value:is_set() then
    return value:read() ---@type string
  else
    if M.exists("master") then
      return "master"
    elseif M.exists("main") then
      return "main"
    end
  end
end

---Determine if a branch exists locally
---@param branch string
---@return boolean
function M.exists(branch)
  local result = git.cli["rev-parse"].verify.quiet
    .args(string.format("refs/heads/%s", branch))
    .call { hidden = true, ignore_error = true }

  return result.code == 0
end

---Determine if a branch name ("origin/master", "fix/bug-1000", etc)
---is a remote branch or a local branch
---@param ref string
---@return nil|string remote
---@return string branch
function M.parse_remote_branch(ref)
  if M.exists(ref) then
    return nil, ref
  end

  return ref:match("^([^/]*)/(.*)$")
end

---@param name string
---@param base_branch? string
---@return boolean
function M.create(name, base_branch)
  return git.cli.branch.args(name, base_branch).call({ await = true }).code == 0
end

---@param name string
---@return boolean
function M.delete(name)
  local input = require("neogit.lib.input")

  local result
  if M.is_unmerged(name) then
    local message = ("'%s' contains unmerged commits! Are you sure you want to delete it?"):format(name)
    if input.get_permission(message) then
      result = git.cli.branch.delete.force.name(name).call { await = true }
    end
  else
    result = git.cli.branch.delete.name(name).call { await = true }
  end

  return result and result.code == 0 or false
end

---Returns current branch name, or nil if detached HEAD
---@return string|nil
function M.current()
  local head = git.repo.state.head.branch
  if head and head ~= "(detached)" then
    return head
  else
    local branch_name = git.cli.branch.current.call({ hidden = true }).stdout
    if #branch_name > 0 then
      return branch_name[1]
    end

    return nil
  end
end

---@return string|nil
function M.current_full_name()
  local current = M.current()
  if current then
    return git.cli["rev-parse"].symbolic_full_name.args(current).call({ hidden = true }).stdout[1]
  end
end

---@param branch? string
---@return string|nil
function M.pushRemote(branch)
  branch = branch or M.current()

  if branch then
    local remote = git.config.get_local("branch." .. branch .. ".pushRemote")
    if remote:is_set() then
      return remote.value
    end
  end
end

---@param branch? string
---@return string|nil
function M.pushRemote_ref(branch)
  branch = branch or M.current()
  local pushRemote = M.pushRemote(branch)

  if branch and pushRemote then
    return string.format("%s/%s", pushRemote, branch)
  end
end

---@return string
function M.pushRemote_label()
  return M.pushRemote_ref() or "pushRemote, setting that"
end

---@return string
function M.pushRemote_remote_label()
  return M.pushRemote() or "pushRemote, setting that"
end

---@return boolean
function M.is_detached()
  return git.repo.state.head.branch == "(detached)"
end

---@return string|nil
function M.set_pushRemote()
  local remotes = git.remote.list()
  local pushDefault = git.config.get("remote.pushDefault")

  local pushRemote
  if #remotes == 1 then
    pushRemote = remotes[1]
  elseif pushDefault:is_set() then
    pushRemote = pushDefault:read()
  else
    pushRemote = FuzzyFinderBuffer.new(remotes):open_async { prompt_prefix = "set pushRemote" }
  end

  assert(type(pushRemote) == "nil" or type(pushRemote) == "string", "pushRemote is not a string or nil?")

  if pushRemote then
    git.config.set(string.format("branch.%s.pushRemote", M.current()), pushRemote)
  end

  return pushRemote
end

---Finds the upstream ref for a branch, or current branch
---When a branch is specified and no upstream exists, returns nil
---@param name string?
---@return string|nil
function M.upstream(name)
  if name then
    local result =
      git.cli["rev-parse"].symbolic_full_name.abbrev_ref(name .. "@{upstream}").call { ignore_error = true }

    if result.code == 0 then
      return result.stdout[1]
    end
  else
    return git.repo.state.upstream.ref
  end
end

---@param name string
---@param destination string?
function M.set_upstream(name, destination)
  git.cli.branch.set_upstream_to(name).args(destination or M.current())
end

---@return string
function M.upstream_label()
  return M.upstream() or "@{upstream}, creating it"
end

---@return string
function M.upstream_remote_label()
  return M.upstream_remote() or "@{upstream}, setting it"
end

---@return string|nil
function M.upstream_remote()
  if git.repo.state.upstream.remote then
    return git.repo.state.upstream.remote
  end

  local remotes = git.remote.list()
  if #remotes == 1 then
    return remotes[1]
  elseif vim.tbl_contains(remotes, "origin") then
    return "origin"
  end
end

---@return string[]
function M.related()
  local current = M.current()
  local related = {}
  local target, upstream, upup

  if current then
    table.insert(related, current)

    target = M.pushRemote(current)
    if target then
      table.insert(related, target)
    end

    upstream = M.upstream(current)
    if upstream then
      table.insert(related, upstream)
    end

    if upstream and vim.tbl_contains(git.refs.list_local_branches(), upstream) then
      upup = M.upstream(upstream)
      if upup then
        table.insert(related, upup)
      end
    end
  else
    table.insert(related, "HEAD")

    if git.rebase.in_progress() then
      table.insert(related, git.rebase.current_HEAD())
    else
      table.insert(related, M.get_recent_local_branches()[1])
    end
  end

  return related
end

---@class BranchStatus
---@field ab string|nil
---@field detached boolean
---@field oid string
---@field head string
---@field upstream string|nil

---@return BranchStatus
function M.status()
  local result = git.cli.status.porcelain(2).branch.call { hidden = true }
  local status = {}
  for _, line in ipairs(result.stdout) do
    if line:match("^# branch") then
      local key, value = line:match("^# branch%.([^%s]+) (.*)$")
      status[key] = value
    else
      break
    end
  end

  status.detached = status.head == "(detached)"

  return status
end

local INITIAL_COMMIT = "(initial)"

---@param state NeogitRepoState
local function update_branch_information(state)
  local status = M.status()

  state.upstream.ref = nil
  state.upstream.remote = nil
  state.upstream.branch = nil
  state.upstream.oid = nil
  state.upstream.commit_message = nil
  state.upstream.abbrev = nil

  state.pushRemote.ref = nil
  state.pushRemote.remote = nil
  state.pushRemote.branch = nil
  state.pushRemote.oid = nil
  state.pushRemote.commit_message = nil
  state.pushRemote.abbrev = nil

  state.head.branch = status.head
  state.head.oid = status.oid
  state.head.detached = status.detached

  if status.oid and status.oid ~= INITIAL_COMMIT then
    state.head.abbrev = git.rev_parse.abbreviate_commit(status.oid)
    state.head.commit_message = git.log.message(status.oid)

    if status.upstream then
      local remote, branch = git.branch.parse_remote_branch(status.upstream)
      state.upstream.remote = remote
      state.upstream.branch = branch
      state.upstream.ref = status.upstream

      local commit = git.log.list({ status.upstream, "--max-count=1" }, nil, {}, true)[1]
      if commit then
        state.upstream.oid = commit.oid
        state.upstream.commit_message = commit.subject
        state.upstream.abbrev = git.rev_parse.abbreviate_commit(commit.oid)
      end
    end

    local pushRemote = git.branch.pushRemote_ref()
    if pushRemote and not status.detached then
      local remote, branch = pushRemote:match("([^/]+)/(.+)")
      state.pushRemote.ref = pushRemote
      state.pushRemote.remote = remote
      state.pushRemote.branch = branch

      local commit = git.log.list({ pushRemote, "--max-count=1" }, nil, {}, true)[1]
      if commit then
        state.pushRemote.oid = commit.oid
        state.pushRemote.commit_message = commit.subject
        state.pushRemote.abbrev = git.rev_parse.abbreviate_commit(commit.oid)
      end
    end
  end
end

M.register = function(meta)
  meta.update_branch_information = update_branch_information
end

return M
