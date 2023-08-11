local a = require("plenary.async")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.commit_select_view.ui")
local config = require("neogit.config")
local util = require("neogit.lib.util")

---@class CommitSelectViewBuffer
---@field commits CommitLogEntry[]
local M = {}
M.__index = M

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

---@param action fun(commit: CommitLogEntry[])
function M:open(action)
  -- TODO: Pass this in as a param instead of reading state from object
  local _, item = require("neogit.status").get_current_section_item()

  ---@type fun(commit: CommitLogEntry[])|nil
  local action = action

  self.buffer = Buffer.create {
    name = "NeogitCommitSelectView",
    filetype = "NeogitCommitSelectView",
    kind = config.values.commit_select_view.kind,
    mappings = {
      v = {
        ["<enter>"] = function()
          local commits = self.buffer.ui:get_commits_in_selection()
          if action and commits[1] then
            vim.schedule(function()
              self:close()
            end)

            action(util.reverse(commits))
            action = nil
          end
        end,
      },
      n = {
        ["<tab>"] = function()
          -- no-op
        end,
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["<enter>"] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if action and commit then
            vim.schedule(function()
              self:close()
            end)

            action { commit }
            action = nil
          end
        end,
      },
    },
    autocmds = {
      ["BufUnload"] = function()
        self.buffer = nil
        if action then
          action {}
        end
      end,
    },
    after = function(buffer, win)
      if win and item and item.commit then
        local found = buffer.ui:find_component(function(c)
          return c.options.oid == item.commit.oid
        end)

        if found then
          vim.api.nvim_win_set_cursor(win, { found.position.row_start, 0 })
        end
      end
      vim.cmd([[setlocal nowrap]])
    end,
    render = function()
      return ui.View(self.commits)
    end,
  }
end

---@type fun(self): CommitLogEntry|nil
--- Select one of more commits under the cursor or visual selection
M.open_async = a.wrap(M.open, 2)

return M
