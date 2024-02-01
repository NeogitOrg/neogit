local config = require("neogit.config")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.status.ui")

local M = {}

-- @class StatusBuffer
-- @field is_open whether the buffer is currently visible
-- @field buffer buffer instance
-- @field state StatusState
-- @see Buffer
-- @see StatusState

function M.new(state)
  local x = {
    is_open = false,
    state = state,
    buffer = nil,
  }
  setmetatable(x, { __index = M })
  return x
end

function M:open(kind)
  kind = kind or config.values.kind

  self.buffer = Buffer.create {
    name = "NeogitStatusNew",
    filetype = "NeogitStatusNew",
    context_highlight = true,
    kind = kind,
    disable_line_numbers = config.values.disable_line_numbers,
    mappings = {
      n = {
        ["<tab>"] = function()
          local fold = self.buffer.ui:get_fold_under_cursor()
          if fold then
            if fold.options.on_open then
              fold.options.on_open(fold, self.buffer.ui)
            else
              local ok, _ = pcall(vim.cmd, "normal! za")
              if ok then
                fold.options.folded = not fold.options.folded
              end
            end
          end
        end,
      },
    },
    initialize = function()
      self.prev_autochdir = vim.o.autochdir

      vim.o.autochdir = false
    end,
    render = function()
      return ui.Status(self.state)
    end,
    after = function()
      vim.cmd([[setlocal nowrap]])
      -- M.watcher = watcher.new(git.repo:git_path():absolute())
    end
  }
end

return M
