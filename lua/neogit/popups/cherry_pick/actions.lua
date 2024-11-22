local M = {}
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")

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
  local ref = FuzzyFinderBuffer.new(refs):open_async({ prompt_prefix = "Squash" })
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--squash")
    git.merge.merge(ref, args)
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
