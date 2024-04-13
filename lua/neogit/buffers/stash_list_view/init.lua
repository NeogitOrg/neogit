local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local StashEntry = require("neogit.lib.git.stash")

---@class StashListBuffer
---@field stashes StashEntry[]
local M = {}
M.__index = M

---Opens a popup for viewing all stashes
---@param stashes StashEntry[]
function M.new(stashes)
  local instance = {
    stashes = stashes
  }

  setmetatable(instance, M)
  return instance
end

function M.close()
  self.buffer:close()
  self.buffer = nil
end

function M.open()
  self.buffer = Buffer.create {
    name = "NeogitStashListView",
    filetype = "NeogitStashView",
    kind = config.values.stash.kind,
    context_higlight = true,
    -- Include mapping to turn on options for git stash refer to git-log(1)
    mappings = {
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["<enter>"] = function()
          -- Still looking for how to view a stash
          -- CommitViewBuffer.new(self.buffer.ui:get_commit_under_cursor(), self.files):open()
        end,
    }
  }
end

return M
