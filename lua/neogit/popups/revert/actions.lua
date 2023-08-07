local M = {}

local a = require("plenary.async")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

---@param popup any
---@return table
local function get_commits(popup)
  local commits
  if popup.state.env.commits[1] then
    commits = util.map(popup.state.env.commits, function(c)
      return c.oid
    end)
  else
    commits = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
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
  require("neogit.status").refresh(true, "revert_commits")
end

return M
