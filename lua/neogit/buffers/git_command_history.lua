local Buffer = require("neogit.lib.buffer")
local Git = require("neogit.lib.git")
local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")

local map = util.map

local text = Ui.text
local col = Ui.col
local row = Ui.row

local M = {}

function M:new(state)
  local this = {
    buffer = nil,
    state = state or Git.cli.history,
    is_open = false,
  }

  setmetatable(this, { __index = M })

  return this
end

function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end

function M:show()
  if self.is_open then
    return
  end
  self.is_open = true

  self.buffer = Buffer.create {
    name = "NeogitGitCommandHistory",
    filetype = "NeogitGitCommandHistory",
    mappings = {
      n = {
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["<tab>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local c = stack[#stack]

          if c then
            c.children[2]:toggle_hidden()
            self.buffer.ui:update()
          end
        end,
      },
    },
    render = function()
      local win_width = vim.fn.winwidth(0)

      return map(self.state, function(item)
        local is_err = item.code ~= 0

        local code = string.format("%3d", item.code)
        local command, _ = item.cmd:gsub(" %-%-no%-pager %-c color%.ui=always %-%-no%-optional%-locks", "")
        local time = string.format("(%3.3f ms)", item.time)
        local stdio = string.format("[%s %3d]", "stdout", #item.stdout)

        local highlight_code = "NeogitCommandCodeNormal"

        if is_err then
          stdio = string.format("[%s %d]", "stderr", #item.stderr)
          highlight_code = "NeogitCommandCodeError"
        end

        local spacing = string.rep(" ", win_width - #code - #command - #time - #stdio - 6)

        return col {
          row {
            text.highlight(highlight_code)(code),
            text(" "),
            text(command),
            text(spacing),
            text.highlight("NeogitCommandTime")(time),
            text(" "),
            text.highlight("NeogitCommandTime")(stdio),
          },
          col
            .hidden(true)
            .padding_left("  | ")
            .highlight("NeogitCommandText")(map(is_err and item.stderr or item.stdout, text)),
        }
      end)
    end,
  }
end

return M
