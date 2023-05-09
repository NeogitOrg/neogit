local util = require("neogit.lib.util")

local Commit = require("neogit.buffers.common").CommitEntry
local Graph = require("neogit.buffers.common").CommitGraph

local M = {}

---@param commits CommitLogEntry[]
---@param args table
---@return table
function M.View(commits, args)
  args.details = true

  return util.filter_map(commits, function(commit)
    if commit.oid then
      return Commit(commit, args)
    elseif args.graph then
      return Graph(commit)
    end
  end)
end

return M
