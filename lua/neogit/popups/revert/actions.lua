local a = require("plenary.async")
local status = require("neogit.status")
local git = require("neogit.lib.git")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

local M = {}

---@param popup any
---@return table
local function get_commits(popup)
  local commits
  if popup.state.env.commits then
    commits = popup.state.env.commits
  else
    commits = { CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async() }
  end

  a.util.scheduler()
  return commits or {}
end

-- TODO: support multiple commits
function M.commits(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  git.revert.commits(commits, popup:get_arguments())
  a.util.scheduler()
  status.refresh(true, "revert_commits")
end

return M
