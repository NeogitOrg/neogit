local Buffer = require("neogit.lib.buffer")
local CommitViewBuffer = require("neogit.buffers.commit_view")
local ui = require("neogit.buffers.log_view.ui")
local config = require("neogit.config")
local CherryPickPopup = require("neogit.popups.cherry_pick")
local util = require("neogit.lib.util")

local M = {}

-- @class LogViewBuffer
-- @field is_open whether the buffer is currently shown
-- @field data the dislayed data
-- @field buffer Buffer
-- @see CommitInfo
-- @see Buffer

--- Creates a new LogViewBuffer
-- @param data the data to display
-- @param show_graph whether we should also render the graph on the left side
-- @return LogViewBuffer
function M.new(data, show_graph)
  local instance = {
    is_open = false,
    data = data,
    show_graph = show_graph,
    buffer = nil,
  }

  setmetatable(instance, { __index = M })

  return instance
end

function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end

function M:open()
  if self.is_open then
    return
  end

  self.is_open = true
  self.buffer = Buffer.create {
    name = "NeogitLogView",
    filetype = "NeogitLogView",
    kind = "tab",
    context_highlight = true,
    mappings = {
      v = {
        ["A"] = function()
          local commits = util.filter_map(
            self.buffer.ui:get_component_stack_in_linewise_selection(),
            function(c)
              if c.tag == "col" then
                return self.data[c.position.row_start].oid
              end
            end
          )

          CherryPickPopup.create { commits = commits }
        end,
      },
      n = {
        ["q"] = function()
          self:close()
        end,
        ["<F10>"] = function()
          self.ui:print_layout_tree { collapse_hidden_components = true }
        end,
        ["A"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          CherryPickPopup.create { commits = { self.data[c.position.row_start] } }
        end,
        ["<enter>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          CommitViewBuffer.new(self.data[c.position.row_start].oid):open()
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

          c.children[2]:toggle_hidden()
          self.buffer.ui:update()
          vim.cmd("normal! zz")
        end,
        ["d"] = function(buffer)
          if not config.ensure_integration("diffview") then
            return
          end
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          buffer:close()
          local dv = require("neogit.integrations.diffview")
          local commit_id = self.data[c.position.row_start].oid
          dv.open("log", commit_id)
        end,
      },
    },
    render = function()
      return ui.LogView(self.data, self.show_graph)
    end,
  }
end

return M
