local util = require("neogit.lib.util")

local Commit = require("neogit.buffers.common").CommitEntry
local Graph = require("neogit.buffers.common").CommitGraph

local M = {}

---@param commits CommitLogEntry[]
---@param internal_args table
---@return table
function M.View(commits, internal_args)
  internal_args.details = true

  return util.filter_map(commits, function(commit)
    if commit.oid then
      return Commit(commit, internal_args)
    elseif internal_args.graph then
      return Graph(commit)
    end
  end)
end

return M
