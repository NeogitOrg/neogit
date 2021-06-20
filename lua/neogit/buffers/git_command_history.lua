local Buffer = require("neogit.lib.buffer")
local Git = require("neogit.lib.git")
local Ui = require 'neogit.lib.ui'
local util = require 'neogit.lib.util'

local map = util.map

local text = Ui.text
local col = Ui.col
local row = Ui.row

local GitCommandHistory = {}
GitCommandHistory.__index = GitCommandHistory

function GitCommandHistory:new(state)
  local this = {
    buffer = nil,
    state = state or Git.cli.history,
    open = false
  }

  setmetatable(this, self)

  return this
end

function GitCommandHistory:show()
  if self.open then
    return
  end

  self.open = true
  self.buffer = Buffer.create {
    name = "NeogitGitCommandHistory",
    filetype = "NeogitGitCommandHistory",
    mappings = {
      n = {
        ["<tab>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]

          if c then
            c.children[2]:toggle_hidden()
            self.buffer.ui:update()
          end
        end
      }
    },
    render = function()
      return map(self.state, function(item)
        local is_err = item.code ~= 0
        local highlight_code = "NeogitCommandCodeNormal"
        if is_err then
          highlight_code = "NeogitCommandCodeError"
        end
        return col {
          row { 
            text.highlight(highlight_code)(string.format("%3d", item.code)), 
            text " ",
            text(item.cmd),
            text " ",
            text.highlight("NeogitCommandTime")(string.format("(%3.3f ms)", item.time)),
            text " ",
            text.highlight("NeogitCommandTime")(string.format("[%s %d]", is_err and "stderr" or "stdout", is_err and #item.stderr or #item.stdout)),
          },
          col
            .hidden(true)
            .padding_left("  | ")
            .highlight("NeogitCommandText")(map(is_err and item.stderr or item.stdout, text))
        }
      end)
    end,
  }
end

return GitCommandHistory
