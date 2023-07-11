local a = require("plenary.async")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local status = require("neogit.status")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

function M.base_branch()
  local value = git.config.get("neogit.baseBranch")
  return value:is_set() and value.value or "master"
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
  end

  status.refresh(true, "rebase_pushremote")
end

function M.onto_pushRemote(popup)
  git.rebase.rebase_onto(git.branch.pushRemote(), popup:get_arguments())
end

-- TODO: Set upstream if unset
function M.onto_upstream(popup)
  git.rebase.rebase_onto(
    string.format("refs/remotes/%s/%s", git.repo.upstream.remote, git.repo.upstream.branch),
    popup:get_arguments()
  )

  a.util.scheduler()
  status.refresh(true, "rebase_upstream")
end

function M.onto_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_async()
  if not target then
    return
  end

  git.rebase.rebase_onto(target, popup:get_arguments())
  a.util.scheduler()
  status.refresh(true, "rebase_elsewhere")
end

function M.interactively(popup)
  local commit = CommitSelectViewBuffer.new(git.log.list()):open_async()
  if not commit then
    return
  end

  git.rebase.rebase_interactive(commit, unpack(popup:get_arguments()))
  a.util.scheduler()
  status.refresh(true, "rebase_interactive")
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
