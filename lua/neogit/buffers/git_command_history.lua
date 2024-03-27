local Buffer = require("neogit.lib.buffer")
local Git = require("neogit.lib.git")
local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")

local map = util.map
local filter_map = util.filter_map

local text = Ui.text
local col = Ui.col
local row = Ui.row

local command_mask =
  vim.pesc(" --no-pager --literal-pathspecs --no-optional-locks -c core.preloadindex=true -c color.ui=always")

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
        ["<c-k>"] = function()
          vim.cmd("normal! zc")

          vim.cmd("normal! k")
          while vim.fn.foldlevel(".") == 0 do
            vim.cmd("normal! k")
          end

          vim.cmd("normal! zo")
          vim.cmd("normal! zz")
        end,
        ["<c-j>"] = function()
          vim.cmd("normal! zc")

          vim.cmd("normal! j")
          while vim.fn.foldlevel(".") == 0 do
            vim.cmd("normal! j")
          end

          vim.cmd("normal! zo")
          vim.cmd("normal! zz")
        end,
        ["<tab>"] = function()
          pcall(vim.cmd, "normal! za")
        end,
      },
    },
    render = function()
      local win_width = vim.fn.winwidth(0)

      return filter_map(self.state, function(item)
        if item.hidden and not os.getenv("NEOGIT_DEBUG") then
          return
        end

        local is_err = item.code ~= 0

        local code = string.format("%3d", item.code)
        local command, _ = item.cmd:gsub(command_mask, "")
        local time = string.format("(%3.3f ms)", item.time)
        local stdio = string.format("[%s %3d]", "stdout", #item.stdout)

        local highlight_code = "NeogitCommandCodeNormal"

        if is_err then
          stdio = string.format("[%s %d]", "stderr", #item.stderr)
          highlight_code = "NeogitCommandCodeError"
        end

        local spacing = string.rep(" ", win_width - #code - #command - #time - #stdio - 6)

        return col({
          row {
            text.highlight("NeogitGraphAuthor")(
              os.getenv("NEOGIT_DEBUG") and (item.hidden and "H" or " ") or ""
            ),
            text.highlight(highlight_code)(code),
            text(" "),
            text(command),
            text(spacing),
            text.highlight("NeogitCommandTime")(time),
            text(" "),
            text.highlight("NeogitCommandTime")(stdio),
          },
          col
            .padding_left("  | ")
            .highlight("NeogitCommandText")(map(util.merge(item.stdout, item.stderr), text)),
        }, { foldable = true, folded = true })
      end)
    end,
  }
end

return M
