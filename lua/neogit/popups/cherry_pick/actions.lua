local M = {}

local git = require("neogit.lib.git")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

---@param popup any
---@return table
local function get_commits(popup)
  local commits
  if #popup.state.env.commits > 0 then
    commits = popup.state.env.commits
  else
    commits = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
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
