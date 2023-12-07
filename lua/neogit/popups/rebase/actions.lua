local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

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
  git.rebase.onto_branch(M.base_branch(), popup:get_arguments())
end

function M.onto_pushRemote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    pushRemote = git.branch.set_pushRemote()
  end

  if pushRemote then
    git.rebase.onto_branch(
      string.format("refs/remotes/%s/%s", pushRemote, git.branch.current()),
      popup:get_arguments()
    )
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

  git.rebase.onto_branch(upstream, popup:get_arguments())
end

function M.onto_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_async()
  if target then
    git.rebase.onto_branch(target, popup:get_arguments())
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
    local args = popup:get_arguments()
    local parent_commit = git.cli["rev-list"].max_count(1).parents.args(commit).call().stdout[1]
    if commit ~= parent_commit then
      commit = vim.split(parent_commit, " ")[2]
    else
      table.insert(args, "--root")
    end

    git.rebase.rebase_interactive(commit, args)
  end
end

function M.subset(popup)
  local newbase = FuzzyFinderBuffer.new(git.branch.get_all_branches())
    :open_async { prompt_prefix = "rebase subset onto" }

  if not newbase then
    return
  end

  local start
  if popup.state.env.commit and git.log.is_ancestor(popup.state.env.commit, "HEAD") then
    start = popup.state.env.commit
  else
    start = CommitSelectViewBuffer.new(git.log.list { "HEAD" }):open_async()[1]
  end

  if not start then
    return
  end

  git.rebase.onto(start, newbase, popup:get_arguments())
end

function M.continue()
  git.rebase.continue()
end

function M.skip()
  git.rebase.skip()
end

function M.edit()
  git.rebase.edit()
end

-- TODO: Extract to rebase lib?
function M.abort()
  if input.get_confirmation("Abort rebase?", { values = { "&Yes", "&No" }, default = 2 }) then
    git.cli.rebase.abort.call_sync()
  end
end

return M
