local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.reflog_view.ui")
local config = require("neogit.config")
local popups = require("neogit.popups")
local status_maps = require("neogit.config").get_reversed_status_maps()
local CommitViewBuffer = require("neogit.buffers.commit_view")

---@class ReflogViewBuffer
---@field entries ReflogEntry[]
---@field header string
local M = {}
M.__index = M

---@param entries ReflogEntry[]|nil
---@param header string
---@return ReflogViewBuffer
function M.new(entries, header)
  local instance = {
    entries = entries,
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

function M:open(_)
  if M.is_open() then
    M.instance.buffer:focus()
    return
  end

  M.instance = self

  self.buffer = Buffer.create {
    name = "NeogitReflogView",
    filetype = "NeogitReflogView",
    kind = config.values.reflog_view.kind,
    header = self.header,
    scroll_header = true,
    status_column = not config.values.disable_signs and "" or nil,
    context_highlight = true,
    active_item_highlight = true,
    mappings = {
      v = {
        [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
        [popups.mapping_for("MergePopup")] = popups.open("merge", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          local items = self.buffer.ui:get_commits_in_selection()
          p {
            section = { name = "log" },
            item = { name = items },
          }
        end),
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
      },
      n = {
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
        [popups.mapping_for("MergePopup")] = popups.open("merge", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("RemotePopup")] = popups.open("remote"),
        [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          local item = self.buffer.ui:get_commit_under_cursor()
          p {
            section = { name = "log" },
            item = { name = item },
          }
        end),
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
        ["<esc>"] = require("neogit.lib.ui.helpers").close_topmost(self),
        [status_maps["Close"]] = require("neogit.lib.ui.helpers").close_topmost(self),
        [status_maps["GoToFile"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            CommitViewBuffer.new(commit):open()
          end
        end,
        [status_maps["PeekFile"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            CommitViewBuffer.new(commit):open()
            self.buffer:focus()
          end
        end,
        [status_maps["OpenOrScrollDown"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            CommitViewBuffer.open_or_scroll_down(commit)
          end
        end,
        [status_maps["OpenOrScrollUp"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            CommitViewBuffer.open_or_scroll_up(commit)
          end
        end,
        [status_maps["PeekUp"]] = function()
          vim.cmd("normal! k")
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            if CommitViewBuffer.is_open() then
              CommitViewBuffer.instance:update(commit)
            else
              CommitViewBuffer.new(commit):open()
            end
          end
        end,
        [status_maps["PeekDown"]] = function()
          vim.cmd("normal! j")
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            if CommitViewBuffer.is_open() then
              CommitViewBuffer.instance:update(commit)
            else
              CommitViewBuffer.new(commit):open()
            end
          end
        end,
      },
    },
    render = function()
      return ui.View(self.entries)
    end,
  }
end

return M
