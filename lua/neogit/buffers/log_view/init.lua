local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.log_view.ui")
local config = require("neogit.config")
local popups = require("neogit.popups")
local notification = require("neogit.lib.notification")

local CommitViewBuffer = require("neogit.buffers.commit_view")

---@class LogViewBuffer
---@field commits CommitLogEntry[]
---@field internal_args table
local M = {}
M.__index = M

---Opens a popup for selecting a commit
---@param commits CommitLogEntry[]|nil
---@param internal_args table|nil
---@return LogViewBuffer
function M.new(commits, internal_args)
  local instance = {
    commits = commits,
    internal_args = internal_args,
    buffer = nil,
  }

  setmetatable(instance, M)

  return instance
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end

function M:open()
  local _, item = require("neogit.status").get_current_section_item()
  self.buffer = Buffer.create {
    name = "NeogitLogView",
    filetype = "NeogitLogView",
    kind = config.values.log_view.kind,
    context_highlight = false,
    mappings = {
      v = {
        ["A"] = popups.open("cherry_pick", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        ["b"] = popups.open("branch", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        ["c"] = popups.open("commit", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        ["P"] = popups.open("push", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        ["r"] = popups.open("rebase", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        ["v"] = popups.open("revert", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        ["X"] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
      },
      n = {
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["A"] = popups.open("cherry_pick", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        ["b"] = popups.open("branch", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        ["c"] = popups.open("commit", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        ["P"] = popups.open("push", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        ["r"] = popups.open("rebase", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        ["v"] = popups.open("revert", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        ["X"] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        ["<enter>"] = function()
          CommitViewBuffer.new(self.buffer.ui:get_commit_under_cursor()):open()
        end,
        ["<c-k>"] = function(buffer)
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          c.children[2].options.hidden = true

          local t_idx = math.max(c.index - 1, 1)
          local target = c.parent.children[t_idx]
          while not target.children[2] do
            t_idx = t_idx - 1
            target = c.parent.children[t_idx]
          end

          target.children[2].options.hidden = false

          buffer.ui:update()
          self.buffer:move_cursor(target.position.row_start)
        end,
        ["<c-j>"] = function(buffer)
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          c.children[2].options.hidden = true

          local t_idx = math.min(c.index + 1, #c.parent.children)
          local target = c.parent.children[t_idx]
          while not target.children[2] do
            t_idx = t_idx + 1
            target = c.parent.children[t_idx]
          end

          target.children[2].options.hidden = false

          buffer.ui:update()
          buffer:move_cursor(target.position.row_start)
          vim.cmd("normal! zz")
        end,
        ["<tab>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]

          if c.children[2] then
            c.children[2]:toggle_hidden()
            self.buffer.ui:update()
          end
        end,
        ["d"] = function()
          if not config.check_integration("diffview") then
            notification.error("Diffview integration must be enabled for log diff")
            return
          end

          local dv = require("neogit.integrations.diffview")
          dv.open("log", self.buffer.ui:get_commit_under_cursor())
        end,
      },
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
      return ui.View(self.commits, self.internal_args)
    end,
  }
end

return M
