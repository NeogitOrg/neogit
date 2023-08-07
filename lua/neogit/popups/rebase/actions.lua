local a = require("plenary.async")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local status = require("neogit.status")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

function M.base_branch()
  local value = git.config.get("neogit.baseBranch")
  if value:is_set() then
    return value.value
  else
    if git.branch.exists("master") then
      return "master"
    elseif git.branch.exists("main") then
      return "main"
    end
  end
end

function M.onto_base(popup)
  git.rebase.rebase_onto(M.base_branch(), popup:get_arguments())
  a.util.scheduler()
  status.refresh(true, "rebase_master")
end

function M.onto_pushRemote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    pushRemote = git.branch.set_pushRemote()
  end

  if pushRemote then
    git.rebase.rebase_onto(
      string.format("refs/remotes/%s/%s", pushRemote, git.branch.current()),
      popup:get_arguments()
    )

    a.util.scheduler()
    status.refresh(true, "rebase_pushremote")
  end
end

function M.onto_upstream(popup)
  local upstream
  if git.repo.upstream.ref then
    upstream = string.format("refs/remotes/%s", git.repo.upstream.ref)
  else
    local target = FuzzyFinderBuffer.new(git.branch.get_remote_branches()):open_async()
    if not target then
      return
    end

    upstream = string.format("refs/remotes/%s", target)
  end

  git.rebase.rebase_onto(upstream, popup:get_arguments())
  a.util.scheduler()
  status.refresh(true, "rebase_upstream")
end

function M.onto_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_async()
  if target then
    git.rebase.rebase_onto(target, popup:get_arguments())
    a.util.scheduler()
    status.refresh(true, "rebase_elsewhere")
  end
end

function M.interactively(popup)
  local commit
  if popup.state.env.commit then
    commit = popup.state.env.commit
  else
    commit = CommitSelectViewBuffer.new(git.log.list()):open_async()[1]
  end

  if commit then
    git.rebase.rebase_interactive(commit, popup:get_arguments())
    a.util.scheduler()
    status.refresh(true, "rebase_interactive")
  end
end

function M.continue()
  git.rebase.continue()
  a.util.scheduler()
  status.refresh(true, "rebase_continue")
end

function M.skip()
  git.rebase.skip()
  a.util.scheduler()
  status.refresh(true, "rebase_skip")
end

-- TODO: Extract to rebase lib?
function M.abort()
  if input.get_confirmation("Abort rebase?", { values = { "&Yes", "&No" }, default = 2 }) then
    git.cli.rebase.abort.call_sync():trim()
    a.util.scheduler()
    status.refresh(true, "rebase_abort")
  end
end

return M
