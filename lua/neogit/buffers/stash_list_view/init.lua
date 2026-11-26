local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local CommitViewBuffer = require("neogit.buffers.commit_view")
local popups = require("neogit.popups")
local util = require("neogit.lib.util")

local git = require("neogit.lib.git")
local ui = require("neogit.buffers.stash_list_view.ui")
local input = require("neogit.lib.input")
local a = require("neogit.lib.async")

---@class StashListBuffer
---@field stashes StashItem[]
local M = {}
M.__index = M

--- Gets all current stashes
function M.new(stashes)
  local instance = {
    stashes = stashes,
  }

  setmetatable(instance, M)
  return instance
end

function M:close()
  if self.buffer then
    self.buffer:win_call(function()
      self.fold_state = self.buffer.ui:get_fold_state()
      self.cursor_state = self.buffer:cursor_line()
      self.view_state = self.buffer:save_view()
    end)

    self.buffer:close()
    if not config.values.keep_hidden_buffers then
      self.buffer = nil
    end
  end
end

--- Creates a buffer populated with output of `git stash list`
--- and supports related operations.
function M:open()
  local status_maps = config.get_reversed_status_maps()
  self.buffer = Buffer.create {
    name = "NeogitStashView",
    filetype = "NeogitStashView",
    header = "Stashes (" .. #self.stashes .. ")",
    scroll_header = true,
    kind = config.values.stash.kind,
    bufhidden = config.values.keep_hidden_buffers and "hide" or nil,
    buflisted = config.values.keep_hidden_buffers or nil,
    context_highlight = true,
    active_item_highlight = true,
    on_detach = function()
      self.buffer = nil
    end,
    on_win_leave = function(buffer)
      if #vim.fn.win_findbuf(buffer.handle) <= 1 then
        buffer:win_call(function()
          self.fold_state = buffer.ui:get_fold_state()
          self.cursor_state = buffer:cursor_line()
          self.view_state = buffer:save_view()
        end)
      end
    end,
    on_win_enter = function()
      if self.fold_state and self.buffer then
        self.buffer.ui:set_fold_state(self.fold_state)
        self.fold_state = nil
      end
      if self.view_state and self.cursor_state and self.buffer then
        self.buffer:win_call(function()
          self.buffer:restore_view(self.view_state, self.cursor_state)
        end)
        self.view_state = nil
        self.cursor_state = nil
      end

      a.void(function()
        git.repo.lib.update_stashes(git.repo.state)
        if self.buffer and self.buffer:is_valid() then
          local fold_state = self.buffer.ui:get_fold_state()
          local cursor, view
          self.buffer:win_call(function()
            cursor = self.buffer:cursor_line()
            view = self.buffer:save_view()
          end)

          self.stashes = git.repo.state.stashes.items
          self.buffer.ui:render(unpack(ui.View(self.stashes)))
          self.buffer.ui:set_fold_state(fold_state)
          if self.buffer:is_visible() and view and cursor then
            self.buffer:win_call(function()
              self.buffer:restore_view(view, cursor)
            end)
          end

          if self.buffer:is_visible() then
            self.buffer:set_header("Stashes (" .. #self.stashes .. ")", false)
          else
            self.buffer.header = "Stashes (" .. #self.stashes .. ")"
          end
        end
      end)()
    end,
    mappings = {
      v = {
        [popups.mapping_for("CherryPickPopup")] = function()
          -- TODO: implement
          -- local stash = self.buffer.ui:get_commit_under_cursor()[1]
          -- if stash then
          --   local stash_item = util.find(self.stashes, function(s)
          --     return s.idx == tonumber(stash:match("stash@{(%d+)}"))
          --   end)
          --
          --   if stash and input.get_permission("Pop stash " .. stash_item.name) then
          --     git.stash.pop(stash)
          --   end
          -- end
        end,
        [status_maps["Discard"]] = function()
          local stashes = self.buffer.ui:get_commits_in_selection()
          if stashes then
            if
              stashes
              and input.get_permission(table.concat(stashes, "\n") .. "\n\nDrop " .. #stashes .. " stashes?")
            then
              for _, stash in ipairs(stashes) do
                git.stash.drop(stash)
              end
            end
          end
        end,
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
            section = { name = "stashes" },
            item = { name = items },
          }
        end),
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
      },
      n = {
        ["V"] = function()
          vim.cmd("norm! V")
        end,
        [popups.mapping_for("CherryPickPopup")] = function()
          local stash = self.buffer.ui:get_commit_under_cursor()
          if stash then
            local stash_item = util.find(self.stashes, function(s)
              return s.idx == tonumber(stash:match("stash@{(%d+)}"))
            end)

            if stash and input.get_permission("Pop stash " .. stash_item.name) then
              git.stash.pop(stash)
            end
          end
        end,
        [status_maps["Discard"]] = function()
          local stash = self.buffer.ui:get_commit_under_cursor()
          if stash then
            local stash_item = util.find(self.stashes, function(s)
              return s.idx == tonumber(stash:match("stash@{(%d+)}"))
            end)

            if stash and input.get_permission("Drop stash " .. stash_item.name) then
              git.stash.drop(stash)
            end
          end
        end,
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
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
            section = { name = "stashes" },
            item = { name = item },
          }
        end),
        [status_maps["YankSelected"]] = function()
          local yank = self.buffer.ui:get_commit_under_cursor()
          if yank then
            vim.fn.setreg("+", yank)
            vim.cmd.echo(string.format("%q", yank))
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
    after = function()
      vim.cmd([[setlocal nowrap]])
    end,
    render = function()
      return ui.View(self.stashes)
    end,
  }
end

return M
