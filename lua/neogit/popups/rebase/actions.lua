local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function base_commit(popup, list, header)
  return popup.state.env.commit or CommitSelectViewBuffer.new(list, git.remote.list(), header):open_async()[1]
end

function M.onto_base(popup)
  git.rebase.onto_branch(git.branch.base_branch(), popup:get_arguments())
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
  if git.repo.state.upstream.ref then
    upstream = string.format("refs/remotes/%s", git.repo.state.upstream.ref)
  else
    local target = FuzzyFinderBuffer.new(git.refs.list_remote_branches()):open_async()
    if not target then
      return
    end

    upstream = string.format("refs/remotes/%s", target)
  end

  git.rebase.onto_branch(upstream, popup:get_arguments())
end

function M.onto_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.refs.list_branches()):open_async()
  if target then
    git.rebase.onto_branch(target, popup:get_arguments())
  end
end

function M.interactively(popup)
  local commit = base_commit(
    popup,
    git.log.list({}, {}, {}, true),
    "Select a commit with <cr> to rebase it and all commits above it, or <esc> to abort"
  )
  if commit then
    if not git.log.is_ancestor(commit, "HEAD") then
      notification.warn("Commit isn't an ancestor of HEAD")
      return
    end

    local args = popup:get_arguments()

    local merges = git.cli["rev-list"].merges.args(commit .. "..HEAD").call({ hidden = true }).stdout
    if merges[1] then
      local choice = input.get_choice("Proceed despite merge in rebase range?", {
        values = { "&continue", "&select other", "&abort" },
        default = 1,
      })

      -- selene: allow(empty_if)
      if choice == "c" then
        -- no-op
      elseif choice == "s" then
        popup.state.env.commit = nil
        M.interactively(popup)
      else
        return
      end
    end

    local parent = git.log.parent(commit)
    if parent then
      commit = commit .. "^"
    else
      table.insert(args, "--root")
    end

    git.rebase.rebase_interactive(commit, args)
  end
end

function M.reword(popup)
  local commit = base_commit(
    popup,
    git.log.list(),
    "Select a commit to with <cr> to reword its message, or <esc> to abort"
  )
  if not commit then
    return
  end

  git.rebase.reword(commit)
end

function M.modify(popup)
  local commit = base_commit(popup, git.log.list(), "Select a commit to edit with <cr>, or <esc> to abort")
  if commit then
    git.rebase.modify(commit)
  end
end

function M.drop(popup)
  local commit = base_commit(popup, git.log.list(), "Select a commit to remove with <cr>, or <esc> to abort")
  if commit then
    git.rebase.drop(commit)
  end
end

function M.subset(popup)
  local newbase = FuzzyFinderBuffer.new(git.refs.list_branches())
    :open_async { prompt_prefix = "rebase subset onto" }
  if not newbase then
    return
  end

  local start
  if popup.state.env.commit and git.log.is_ancestor(popup.state.env.commit, "HEAD") then
    start = popup.state.env.commit
  else
    start = CommitSelectViewBuffer.new(
      git.log.list { "HEAD" },
      git.remote.list(),
      "Select a commit with <cr> to rebase it and commits above it onto " .. newbase .. ", or <esc> to abort"
    )
      :open_async()[1]
  end

  if start then
    git.rebase.onto(start, newbase, popup:get_arguments())
  end
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

function M.autosquash(popup)
  local base
  if popup.state.env.commit and git.log.is_ancestor(popup.state.env.commit, "HEAD") then
    base = popup.state.env.commit
  else
    base = git.rebase.merge_base_HEAD()
  end

  if base then
    git.rebase.onto(
      "HEAD",
      base,
      util.deduplicate(util.merge(popup:get_arguments(), { "--autosquash", "--keep-empty" }))
    )
  end
end

-- TODO: Extract to rebase lib?
function M.abort()
  if input.get_permission("Abort rebase?") then
    git.rebase.abort()
  end
end

return M
