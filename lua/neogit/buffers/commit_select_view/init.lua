local a = require("plenary.async")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.commit_select_view.ui")

---@class CommitSelectViewBuffer
---@field commits CommitLogEntry[]
local M = {}
M.__index = M

local function line_pos()
  return vim.fn.getpos(".")[2]
end

---Opens a popup for selecting a commit
---@param commits CommitLogEntry[]
---@return CommitSelectViewBuffer
function M.new(commits, action)
  local instance = {
    action = action,
    commits = commits,
    buffer = nil,
  }

  setmetatable(instance, M)

  return instance
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end

---@param action fun(commit: CommitLogEntry|nil)|nil
function M:open(action)
  self.buffer = Buffer.create {
    name = "NeogitCommitSelectView",
    filetype = "NeogitCommitSelectView",
    kind = "split",
    mappings = {
      n = {
        ["<enter>"] = function()
          local pos = line_pos()
          if action then
            vim.schedule(function()
              self:close()
            end)

            action(self.commits[pos])
            action = nil
          end
        end,
      },
    },
    autocmds = {
      ["BufUnload"] = function()
        self.buffer = nil
        if action then
          action(nil)
        end
      end,
    },
    render = function()
      return ui.View(self.commits)
    end,
  }
end

---@type fun(self): CommitLogEntry|nil
M.open_async = a.wrap(M.open, 2)

return M
