local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.diff.ui")
local git = require("neogit.lib.git")
local config = require("neogit.config")

local api = vim.api

---@class DiffBuffer
---@field buffer Buffer
---@field open fun(self): DiffBuffer
---@field close fun()
---@field stats table
---@field diffs table
---@field header string
---@see Buffer
---@see Ui
local M = {}
M.__index = M

---@param header string
---@return DiffBuffer
function M:new(header)
  local instance = {
    buffer = nil,
    header = header,
    stats = git.diff.staged_stats(),
    diffs = vim.tbl_map(function(item)
      return item.diff
    end, git.repo.state.staged.items),
  }

  setmetatable(instance, self)
  return instance
end

--- Closes the DiffBuffer
function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end
end

---Opens the DiffBuffer
---If already open will close the buffer
---@return DiffBuffer
function M:open()
  if vim.tbl_isempty(self.stats.files) then
    return self
  end

  local status_maps = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitDiffView",
    filetype = "NeogitDiffView",
    status_column = not config.values.disable_signs and "" or nil,
    kind = config.values.commit_editor.staged_diff_split_kind,
    context_highlight = not config.values.disable_context_highlighting,
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
        [status_maps["Close"]] = function()
          self:close()
        end,
      },
    },
    render = function()
      return ui.DiffView(self.header, self.stats, self.diffs)
    end,
    after = function()
      vim.cmd("normal! zR")
      vim.wo.colorcolumn = ""
    end,
  }

  return self
end

return M
