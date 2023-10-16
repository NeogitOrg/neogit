local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.reflog_view.ui")
local config = require("neogit.config")
local popups = require("neogit.popups")
local notification = require("neogit.lib.notification")

local CommitViewBuffer = require("neogit.buffers.commit_view")

---@class ReflogViewBuffer
---@field entries ReflogEntry[]
local M = {}
M.__index = M

---@param entries ReflogEntry[]|nil
---@return ReflogViewBuffer
function M.new(entries)
  local instance = {
    entries = entries,
    buffer = nil,
  }

  setmetatable(instance, M)

  return instance
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end

function M:open(_)
  self.buffer = Buffer.create {
    name = "NeogitReflogView",
    filetype = "NeogitReflogView",
    kind = config.values.reflog_view.kind,
    context_highlight = true,
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
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          CommitViewBuffer.new(stack[#stack].options.oid):open()
        end,
        ["d"] = function()
          if not config.check_integration("diffview") then
            notification.error("Diffview integration must be enabled for reflog diff")
            return
          end

          local dv = require("neogit.integrations.diffview")
          dv.open("log", self.buffer.ui:get_commit_under_cursor())
        end,
      },
    },
    after = function()
      vim.cmd([[setlocal nowrap]])
    end,
    render = function()
      return ui.View(self.entries)
    end,
  }
end

return M
