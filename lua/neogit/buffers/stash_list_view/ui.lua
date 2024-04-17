local util = require("neogit.lib.util")

local Stash = require("neogit.buffers.common").Stash
local StashEntry = require("neogit.lib.git.stash").StashEntry

local M = {}

---@param stashes StashEntry[]
---@return table
function M.View(stashes)
  return Stash(stashes)
end

return M
