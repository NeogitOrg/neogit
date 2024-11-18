local a = require("plenary.async")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.commit_select_view.ui")
local config = require("neogit.config")
local util = require("neogit.lib.util")
local status_maps = require("neogit.config").get_reversed_status_maps()

---@class CommitSelectViewBuffer
---@field commits CommitLogEntry[]
---@field remotes string[]
---@field header string|nil
local M = {}
M.__index = M

---Opens a popup for selecting a commit
---@param commits CommitLogEntry[]|nil
---@param remotes string[]
---@param header? string
---@return CommitSelectViewBuffer
function M.new(commits, remotes, header)
  local instance = {
    commits = commits,
    remotes = remotes,
    header = header,
    buffer = nil,
  }

  setmetatable(instance, M)

  return instance
end

function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end

  M.instance = nil
end

---@return boolean
function M.is_open()
  return (M.instance and M.instance.buffer and M.instance.buffer:is_visible()) == true
end

---@param action fun(commit: CommitLogEntry[])
function M:open(action)
  if M.is_open() then
    M.instance.buffer:focus()
    return
  end

  M.instance = self

  ---@type fun(commit: string[])|nil
  local action = action

  self.buffer = Buffer.create {
    name = "NeogitCommitSelectView",
    filetype = "NeogitCommitSelectView",
    status_column = not config.values.disable_signs and "" or nil,
    kind = config.values.commit_select_view.kind,
    header = self.header or "Select a commit with <cr>, or <esc> to abort",
    scroll_header = true,
    mappings = {
      v = {
        ["<enter>"] = function()
          local commits = self.buffer.ui:get_commits_in_selection()
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
        [status_maps["YankSelected"]] = function()
          local yank = self.buffer.ui:get_commit_under_cursor()
          if yank then
            yank = string.format("'%s'", yank)
            vim.cmd.let("@+=" .. yank)
            vim.cmd.echo(yank)
          else
            vim.cmd("echo ''")
          end
        end,
        ["<esc>"] = function()
          self:close()
        end,
        ["<enter>"] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if action and commit then
            vim.schedule(function()
              self:close()
            end)

            action { commit }
            action = nil
          end
        end,
      },
    },
    on_detach = function()
      self.buffer = nil
      if action then
        action {}
      end
    end,
    render = function()
      return ui.View(self.commits, self.remotes)
    end,
  }
end

---@type fun(self): CommitLogEntry|nil
--- Select one of more commits under the cursor or visual selection
M.open_async = a.wrap(M.open, 2)

return M
