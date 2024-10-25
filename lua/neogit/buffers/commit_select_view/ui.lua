local util = require("neogit.lib.util")

local Commit = require("neogit.buffers.common").CommitEntry
local Graph = require("neogit.buffers.common").CommitGraph

local M = {}

---@param commits CommitLogEntry[]
---@param remotes string[]
---@return table
function M.View(commits, remotes)
  return util.filter_map(commits, function(commit)
    if commit.oid then
      return Commit(commit, remotes, { graph = true, decorate = true })
    else
      return Graph(commit, #commits[1].abbreviated_commit + 1)
    end
  end)
end

return M
