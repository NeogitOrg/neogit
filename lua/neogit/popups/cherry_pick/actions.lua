local M = {}
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

---@param popup any
---@return table
local function get_commits(popup)
  local commits
  if #popup.state.env.commits > 0 then
    commits = popup.state.env.commits
  else
    commits = CommitSelectViewBuffer.new(
      git.log.list { "--max-count=256" },
      git.remote.list(),
      "Select one or more commits to cherry pick with <cr>, or <esc> to abort"
    ):open_async()
  end

  return commits or {}
end

function M.pick(popup)
  local commits = get_commits(popup)
  if #commits == 0 then
    return
  end

  git.cherry_pick.pick(commits, popup:get_arguments())
end

function M.apply(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  git.cherry_pick.apply(commits, popup:get_arguments())
end

function M.squash(popup)
  local refs = util.merge(popup.state.env.commits, git.refs.list_branches(), git.refs.list_tags())
  local ref = FuzzyFinderBuffer.new(refs):open_async { prompt_prefix = "Squash" }
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--squash")
    git.merge.merge(ref, args)
  end
end

function M.donate(popup)
  local head = git.rev_parse.oid("HEAD")

  local commits
  if #popup.state.env.commits > 1 then
    commits = popup.state.env.commits
  else
    local ref = FuzzyFinderBuffer.new(util.merge(popup.state.env.commits, git.refs.list_branches()))
      :open_async { prompt_prefix = "Donate" }
    if not git.log.is_ancestor(head, git.rev_parse.oid(ref)) then
      return notification.error("Cannot donate cherries that are not reachable from HEAD")
    end

    if ref == popup.state.env.commits[1] then
      commits = popup.state.env.commits
    else
      commits = util.map(git.cherry.list(head, ref), function(cherry)
        return cherry.oid or cherry
      end)
    end
  end

  local src = git.branch.is_detached() and head or git.branch.current()

  local prefix = string.format("Move %d cherr%s to branch", #commits, #commits > 1 and "ies" or "y")
  local dst = FuzzyFinderBuffer.new(git.refs.list_branches()):open_async { prompt_prefix = prefix }

  if dst then
    git.cherry_pick.move(commits, src, dst, popup:get_arguments())
  end
end

function M.continue()
  git.cherry_pick.continue()
end

function M.skip()
  git.cherry_pick.skip()
end

function M.abort()
  git.cherry_pick.abort()
end

return M
