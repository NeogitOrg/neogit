local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.reflog_view.ui")
local config = require("neogit.config")
local popups = require("neogit.popups")
local commit_view_maps = require("neogit.config").get_reversed_commit_view_maps()
local CommitViewBuffer = require("neogit.buffers.commit_view")
local notification = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require("neogit.lib.async")

---@class ReflogViewBuffer
---@field entries ReflogEntry[]
---@field header string
---@field fetch_func? fun(): ReflogEntry[]
local M = {}
M.__index = M

---@param entries ReflogEntry[]|nil
---@param header string
---@param fetch_func? fun(): ReflogEntry[]
---@return ReflogViewBuffer
function M.new(entries, header, fetch_func)
  local instance = {
    entries = entries,
    header = header,
    fetch_func = fetch_func,
    buffer = nil,
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

  if not config.values.keep_hidden_buffers then
    M.instance = nil
  end
end

---@return boolean
function M.is_open()
  return Buffer.is_open(M.instance)
end

function M:open(_)
  if M.is_open() then
    M.instance.buffer:focus()
    return
  end

  M.instance = self
  local status_maps = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitReflogView",
    filetype = "NeogitReflogView",
    kind = config.values.reflog_view.kind,
    bufhidden = config.values.keep_hidden_buffers and "hide" or nil,
    buflisted = config.values.keep_hidden_buffers or nil,
    header = self.header,
    scroll_header = true,
    status_column = not config.values.disable_signs and "" or nil,
    context_highlight = true,
    active_item_highlight = true,
    on_detach = function()
      self.buffer = nil
      if M.instance == self then
        M.instance = nil
      end
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

      if self.fetch_func then
        a.void(function()
          local entries = self.fetch_func()
          if self.buffer and self.buffer:is_valid() then
            local fold_state = self.buffer.ui:get_fold_state()
            local cursor, view
            self.buffer:win_call(function()
              cursor = self.buffer:cursor_line()
              view = self.buffer:save_view()
            end)

            self.entries = entries
            self.buffer.ui:render(unpack(ui.View(self.entries)))
            self.buffer.ui:set_fold_state(fold_state)
            if self.buffer:is_visible() and view and cursor then
              self.buffer:win_call(function()
                self.buffer:restore_view(view, cursor)
              end)
            end
          end
        end)()
      end
    end,
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
          local items = self.buffer.ui:get_ordered_commits_in_selection()
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
        [commit_view_maps["OpenCommitLinkInBrowser"]] = function()
          if not vim.ui.open then
            notification.warn("Requires Neovim >= 0.10")
            return
          end

          local oid = self.buffer.ui:get_commit_under_cursor()
          if not oid then
            return
          end

          local uri = git.remote.commit_url(oid)
          if uri then
            notification.info(("Opening %q in your browser."):format(uri))
            vim.ui.open(uri)
          else
            notification.warn("Couldn't determine commit URL to open")
          end
        end,
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
    render = function()
      return ui.View(self.entries)
    end,
  }
end

return M
