local Buffer = require("neogit.lib.buffer")
local util = require("neogit.lib.util")
local ui = require("neogit.buffers.log_view.ui")
local config = require("neogit.config")

local CommitViewBuffer = require("neogit.buffers.commit_view")
local CherryPickPopup = require("neogit.popups.cherry_pick")

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
  self.buffer = Buffer.create {
    name = "NeogitLogView",
    filetype = "NeogitLogView",
    kind = "tab",
    context_highlight = false,
    mappings = {
      v = {
        ["A"] = function()
          local commits = util.filter_map(
            self.buffer.ui:get_component_stack_in_linewise_selection(),
            function(c)
              if c.options.oid then
                return c.options.oid
              end
            end
          )

          CherryPickPopup.create { commits = commits }
        end,
        ["V"] = function()
          print("TODO: Revert")
        end,
      },
      n = {
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["A"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          CherryPickPopup.create { commits = { stack[#stack].options.oid } }
        end,
        ["V"] = function()
          print("TODO: Revert")
        end,
        ["<enter>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          CommitViewBuffer.new(stack[#stack].options.oid):open()
        end,
        ["<c-k>"] = function(buffer)
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          c.children[2].options.hidden = true

          local t_idx = math.max(c.index - 1, 1)
          local target = c.parent.children[t_idx]
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
          if not config.ensure_integration("diffview") then
            return
          end

          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local dv = require("neogit.integrations.diffview")
          dv.open("log", stack[#stack].options.oid)
        end,
      },
    },
    after = function()
      vim.cmd([[setlocal nowrap]])
    end,
    render = function()
      return ui.View(self.commits, self.internal_args)
    end,
  }
end

return M
