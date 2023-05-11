local util = require("neogit.lib.util")

local Commit = require("neogit.buffers.common").CommitEntry
local Graph = require("neogit.buffers.common").CommitGraph

local M = {}

---@param commits CommitLogEntry[]
---@return table
function M.View(commits)
  return util.filter_map(commits, function(commit)
    if commit.oid then
      return Commit(commit, { graph = true })
    else
      return Graph(commit)
    end
  end)
end

return M
