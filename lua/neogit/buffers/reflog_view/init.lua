local Buffer = require("neogit.lib.buffer")
local util = require("neogit.lib.util")
local ui = require("neogit.buffers.reflog_view.ui")
local config = require("neogit.config")

local CommitViewBuffer = require("neogit.buffers.commit_view")
local CherryPickPopup = require("neogit.popups.cherry_pick")
local RevertPopup = require("neogit.popups.revert")

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

function M:open()
  self.buffer = Buffer.create {
    name = "NeogitReflogView",
    filetype = "NeogitReflogView",
    kind = config.values.reflog_view.kind,
    context_highlight = true,
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
        ["v"] = function()
          -- local commits = util.filter_map(
          --   self.buffer.ui:get_component_stack_in_linewise_selection(),
          --   function(c)
          --     if c.options.oid then
          --       return c.options.oid
          --     end
          --   end
          -- )

          print("Multiple commits not yet implimented")
          -- RevertPopup.create(commits)
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
        ["v"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          RevertPopup.create { commits = { stack[#stack].options.oid } }
        end,
        ["<enter>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          CommitViewBuffer.new(stack[#stack].options.oid):open()
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
      return ui.View(self.entries)
    end,
  }
end

return M
