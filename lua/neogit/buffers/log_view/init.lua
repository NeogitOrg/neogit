local Buffer = require("neogit.lib.buffer")
local CommitViewBuffer = require 'neogit.buffers.commit_view'
local ui = require 'neogit.buffers.log_view.ui'

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
    buffer = nil
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
    kind = "split",
    mappings = {
      n = {
        ["q"] = function()
          self:close()
        end,
        ["F10"] = function()
          self.ui:print_layout_tree { collapse_hidden_components = true }
        end,
        ["<enter>"] = function(buffer)
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]
          buffer:close()
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
          vim.fn.feedkeys "zz"
        end,
        ["<tab>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]

          c.children[2]:toggle_hidden() 
          self.buffer.ui:update()
          vim.fn.feedkeys "zz"
        end
      }
    },
    render = function()
      return ui.LogView(self.data, self.show_graph)
    end
  }
end

return M
