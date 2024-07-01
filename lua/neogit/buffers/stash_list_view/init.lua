local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local CommitViewBuffer = require("neogit.buffers.commit_view")

local git = require("neogit.lib.git")
local ui = require("neogit.buffers.stash_list_view.ui")

---@class StashListBuffer
---@field stashes StashEntry[]
local M = {}
M.__index = M

--- Gets all current stashes
function M.new(stashes)
  local instance = {
    stashes = stashes,
  }

  setmetatable(instance, M)
  return instance
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end

--- Creates a buffer populated with output of `git stash list`
--- and supports related operations.
function M:open()
  self.buffer = Buffer.create {
    name = "NeogitStashView",
    filetype = "NeogitStashView",
    kind = config.values.stash.kind,
    context_highlight = true,
    -- Define the available mappings here. `git stash list` has the same options
    -- as `git log` refer to git-log(1) for more info.
    mappings = {
      n = {
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["<enter>"] = function()
          CommitViewBuffer.new(git.rev_parse.oid(self.buffer.ui:get_commit_under_cursor())):open("tab")
        end,
      },
    },
    after = function()
      vim.cmd([[setlocal nowrap]])
    end,
    render = function()
      return ui.View(self.stashes)
    end,
  }
end

return M
