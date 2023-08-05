local a = require("plenary.async")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.commit_select_view.ui")
local config = require("neogit.config")
local util = require("neogit.lib.util")

---@class CommitSelectViewBuffer
---@field commits CommitLogEntry[]
local M = {}
M.__index = M

---Opens a popup for selecting a commit
---@param commits CommitLogEntry[]|nil
---@return CommitSelectViewBuffer
function M.new(commits)
  local instance = {
    commits = commits,
    buffer = nil,
  }

  setmetatable(instance, M)

  return instance
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end

---@param action fun(commit: CommitLogEntry|nil)|nil
function M:open(action)
  -- TODO: Pass this in as a param instead of reading state from object
  local _, item = require("neogit.status").get_current_section_item()

  local commit_at_cursor

  if item and item.commit then
    commit_at_cursor = item.commit
  end

  self.buffer = Buffer.create {
    name = "NeogitCommitSelectView",
    filetype = "NeogitCommitSelectView",
    kind = config.values.commit_select_view.kind,
    mappings = {
      v = {
        ["<enter>"] = function()
          local commits = util.filter_map(
            self.buffer.ui:get_component_stack_in_linewise_selection(),
            function(c)
              if c.options.oid then
                return c.options.oid
              end
            end
          )


          if action and commits[1] then
            vim.schedule(function()
              self:close()
            end)

            action(util.reverse(commits))
            action = nil
          end
        end,
      },
      n = {
        ["<tab>"] = function()
          -- no-op
        end,
        ["q"] = function()
          self:close()
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["<enter>"] = function()
          local stack = self.buffer.ui:get_component_stack_under_cursor()
          local commit = stack[#stack].options.oid

          if action and commit then
            vim.schedule(function()
              self:close()
            end)

            action(commit)
            action = nil
          end
        end,
      },
    },
    autocmds = {
      ["BufUnload"] = function()
        self.buffer = nil
        if action then
          action(nil)
        end
      end,
    },
    after = function()
      if commit_at_cursor then
        vim.fn.search(commit_at_cursor.oid)
      end
      vim.cmd([[setlocal nowrap]])
    end,
    render = function()
      return ui.View(self.commits)
    end,
  }
end

---@type fun(self): CommitLogEntry|nil
M.open_async = a.wrap(M.open, 2)

return M
