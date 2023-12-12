local cli = require("neogit.lib.git.cli")
local config_lib = require("neogit.lib.git.config")
local config = require("neogit.config")
local util = require("neogit.lib.util")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function parse_branches(branches, include_current)
  include_current = include_current or false
  local other_branches = {}

  local remotes = "^remotes/(.*)"
  local head = "^(.*)/HEAD"
  local ref = " %-> "
  local detached = "^%(HEAD detached at %x%x%x%x%x%x%x%x%)$"
  local pattern = include_current and "^[* ] (.+)" or "^  (.+)"

  for _, b in ipairs(branches) do
    local branch_name = b:match(pattern)
    if branch_name then
      local name = branch_name:match(remotes) or branch_name
      if name and not name:match(ref) and not name:match(head) and not name:match(detached) then
        table.insert(other_branches, name)
      end
    end
  end

  return other_branches
end

function M.get_recent_local_branches()
  local valid_branches = M.get_local_branches()

  local branches = util.filter_map(
    cli.reflog.show.format("%gs").date("relative").call_sync().stdout,
    function(ref)
      local name = ref:match("^checkout: moving from .* to (.*)$")
      if vim.tbl_contains(valid_branches, name) then
        return name
      end
    end
  )

  return util.deduplicate(branches)
end

function M.checkout(name, args)
  cli.checkout.branch(name).arg_list(args or {}).call_sync()

  if config.values.fetch_after_checkout then
    local fetch = require("neogit.lib.git.fetch")
    local pushRemote = M.pushRemote_ref()
    local upstream = M.upstream()

    if upstream and upstream == pushRemote then
      fetch.fetch_upstream()
    else
      if upstream then
        fetch.fetch_upstream()
      end
      if pushRemote then
        fetch.fetch_pushRemote()
      end
    end
  end
end

function M.track(name, args)
  cli.checkout.track(name).arg_list(args or {}).call_sync()
end

function M.get_local_branches(include_current)
  local branches = cli.branch.list(config.values.sort_branches).call_sync().stdout
  return parse_branches(branches, include_current)
end

function M.get_remote_branches(include_current)
  local branches = cli.branch.remotes.list(config.values.sort_branches).call_sync().stdout
  return parse_branches(branches, include_current)
end

function M.get_all_branches(include_current)
  return util.merge(M.get_local_branches(include_current), M.get_remote_branches(include_current))
end

function M.is_unmerged(branch, base)
  return cli.cherry.arg_list({ base or "master", branch }).call_sync().stdout[1] ~= nil
end

function M.exists(branch)
  local check = cli["rev-parse"].verify
    .args(string.format("refs/heads/%s", branch))
    .call_sync({ ignore_error = true }).stdout[1]

  return check ~= nil
end

function M.create(name)
  cli.branch.name(name).call_interactive()
end

function M.delete(name)
  local input = require("neogit.lib.input")

  local result
  if M.is_unmerged(name) then
    if
      input.get_confirmation(
        string.format("'%s' contains unmerged commits! Are you sure you want to delete it?", name),
        { values = { "&Yes", "&No" }, default = 2 }
      )
    then
      result = cli.branch.delete.force.name(name).call_sync()
    end
  else
    result = cli.branch.delete.name(name).call_sync()
  end

  return result and result.code == 0 or false
end

function M.current()
  local head = require("neogit.lib.git").repo.head.branch
  if head then
    return head
  else
    local branch_name = cli.branch.current.call_sync().stdout
    if #branch_name > 0 then
      return branch_name[1]
    end
    return nil
  end
end

function M.current_full_name()
  local current = M.current()
  if current then
    return cli["rev-parse"].symbolic_full_name.args(current).call_sync().stdout[1]
  end
end

function M.pushRemote(branch)
  branch = branch or M.current()

  if branch then
    local remote = config_lib.get("branch." .. branch .. ".pushRemote")
    if remote:is_set() then
      return remote.value
    end
  end
end

function M.pushRemote_ref(branch)
  branch = branch or M.current()
  local pushRemote = M.pushRemote(branch)

  if branch and pushRemote then
    return string.format("%s/%s", pushRemote, branch)
  end
end

function M.pushRemote_label()
  return M.pushRemote_ref() or "pushRemote, setting that"
end

function M.pushRemote_remote_label()
  return M.pushRemote() or "pushRemote, setting that"
end

function M.is_detached()
  return require("neogit.lib.git").repo.head.branch == "(detached)"
end

function M.set_pushRemote()
  local remotes = require("neogit.lib.git").remote.list()
  local pushDefault = require("neogit.lib.git").config.get("remote.pushDefault")

  local pushRemote
  if #remotes == 1 then
    pushRemote = remotes[1]
  elseif pushDefault:is_set() then
    pushRemote = pushDefault:read()
  else
    pushRemote = FuzzyFinderBuffer.new(remotes):open_async { prompt_prefix = "set pushRemote" }
  end

  if pushRemote then
    config_lib.set(string.format("branch.%s.pushRemote", M.current()), pushRemote)
  end

  return pushRemote
end

function M.upstream()
  return require("neogit.lib.git").repo.upstream.ref
end

function M.upstream_label()
  return M.upstream() or "@{upstream}, creating it"
end

function M.upstream_remote_label()
  return M.upstream_remote() or "@{upstream}, setting it"
end

function M.upstream_remote()
  local git = require("neogit.lib.git")
  local remote = git.repo.upstream.remote

  if not remote then
    local remotes = git.remote.list()
    if #remotes == 1 then
      remote = remotes[1]
    elseif vim.tbl_contains(remotes, "origin") then
      remote = "origin"
    end
  end

  return remote
end

local function update_branch_information(state)
  local git = require("neogit.lib.git")

  if state.head.oid ~= "(initial)" then
    local result = cli.log.max_count(1).pretty("%B").call { hidden = true }

    state.head.commit_message = result.stdout[1]

    if state.upstream.ref then
      local commit = git.log.list({ state.upstream.ref, "--max-count=1" }, {}, {}, true)[1]
      -- May be done earlier by `update_status`, but this function can be called separately
      if commit then
        state.upstream.commit_message = commit.subject
        state.upstream.abbrev = git.rev_parse.abbreviate_commit(commit.oid)
      end
    end

    local pushRemote = require("neogit.lib.git").branch.pushRemote_ref()
    if pushRemote and not git.branch.is_detached() then
      local commit = git.log.list({ pushRemote, "--max-count=1" }, {}, {}, true)[1]
      if commit then
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
