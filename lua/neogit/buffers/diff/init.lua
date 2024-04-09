local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.diff.ui")
local git = require("neogit.lib.git")
local status_maps = require("neogit.config").get_reversed_status_maps()

local api = vim.api

--- @class DiffBuffer
--- @field buffer Buffer
--- @field open fun(self, kind: string)
--- @field close fun()
--- @see Buffer
--- @see Ui
local M = {
  instance = nil,
}

M.__index = M

function M:new()
  local instance = {
    buffer = nil,
  }

  setmetatable(instance, self)
  return instance
end

--- Closes the Diff
function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end

  M.instance = nil
end

---Opens the DiffBuffer
---If already open will close the buffer
function M:open()
  M.instance = self

  self.buffer = Buffer.create {
    name = "NeogitDiffView",
    filetype = "NeogitDiffView",
    kind = "split",
    context_highlight = true,
    mappings = {
      n = {
        ["{"] = function() -- Goto Previous
          local function previous_hunk_header(self, line)
            local c = self.buffer.ui:get_component_on_line(line, function(c)
              return c.options.tag == "Diff" or c.options.tag == "Hunk"
            end)

            if c then
              local first, _ = c:row_range_abs()
              if vim.fn.line(".") == first then
                first = previous_hunk_header(self, line - 1)
              end

              return first
            end
          end

          local previous_header = previous_hunk_header(self, vim.fn.line("."))
          if previous_header then
            api.nvim_win_set_cursor(0, { previous_header, 0 })
            vim.cmd("normal! zt")
          end
        end,
        ["}"] = function() -- Goto next
          local c = self.buffer.ui:get_component_under_cursor(function(c)
            return c.options.tag == "Diff" or c.options.tag == "Hunk"
          end)

          if c then
            if c.options.tag == "Diff" then
              self.buffer:move_cursor(vim.fn.line(".") + 1)
            else
              local _, last = c:row_range_abs()
              if last == vim.fn.line("$") then
                self.buffer:move_cursor(last)
              else
                self.buffer:move_cursor(last + 1)
              end
            end
            vim.cmd("normal! zt")
          end
        end,
        [status_maps["Toggle"]] = function()
          pcall(vim.cmd, "normal! za")
        end,
      },
    },
    render = function()
      local stats = git.diff.staged_stats()

      local diffs = vim.tbl_map(function(item)
        return item.diff
      end, git.repo.state.staged.items)

      return ui.DiffView(stats, diffs)
    end,
    after = function()
      vim.cmd("normal! zR")
    end,
  }
end

return M
