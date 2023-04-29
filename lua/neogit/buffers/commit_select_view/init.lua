local a = require("plenary.async")
local Buffer = require("neogit.lib.buffer")
local util = require("neogit.lib.util")
local ui = require("neogit.buffers.commit_select_view.ui")

---@class CommitSelectViewBuffer
---@field commits CommitLogEntry[]
local M = {}
M.__index = M

local function line_pos()
  return vim.fn.getpos(".")[2]
end

---Opens a popup for selecting a commit
---@param commits CommitLogEntry[]|nil
---@return CommitSelectViewBuffer
function M.new(commits)
  local instance = {
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
  local _, item = require("neogit.status").get_current_section_item()

  local commit_at_cursor

  if item and item.commit then
    commit_at_cursor = item.commit
  end

  self.buffer = Buffer.create {
    name = "NeogitCommitSelectView",
    filetype = "NeogitCommitSelectView",
    kind = "split",
    mappings = {
      n = {
        ["q"] = function()
          self:close()
        end,
        ["<enter>"] = function()
          local pos = line_pos()
          local oid = vim.api.nvim_buf_get_lines(0, pos - 1, pos, true)[1]:match("^(.-) ")
          local commit = util.find(self.commits, function(c)
            return c.oid and c.oid:match("^" .. oid) and oid ~= ""
          end)

          if action and commit then
            vim.schedule(function()
              self:close()
            end)

            action(commit)
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
    after = function()
      vim.cmd([[execute "resize" . (line("$") + 1)]])

      if commit_at_cursor then
        vim.fn.search(commit_at_cursor.oid)
      end
    end,
    render = function()
      return ui.View(self.commits)
    end,
  }
end

---@type fun(self): CommitLogEntry|nil
M.open_async = a.wrap(M.open, 2)

return M
