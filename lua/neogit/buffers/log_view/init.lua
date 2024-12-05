local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.log_view.ui")
local config = require("neogit.config")
local popups = require("neogit.popups")
local status_maps = require("neogit.config").get_reversed_status_maps()
local CommitViewBuffer = require("neogit.buffers.commit_view")
local util = require("neogit.lib.util")
local a = require("plenary.async")

---@class LogViewBuffer
---@field commits CommitLogEntry[]
---@field remotes string[]
---@field internal_args table
---@field files string[]
---@field buffer Buffer
---@field header string
---@field fetch_func fun(offset: number): CommitLogEntry[]
---@field refresh_lock Semaphore
local M = {}
M.__index = M

---Opens a popup for selecting a commit
---@param commits CommitLogEntry[]|nil
---@param internal_args table|nil
---@param files string[]|nil list of files to filter by
---@param fetch_func fun(offset: number): CommitLogEntry[]
---@param header string
---@param remotes string[]
---@return LogViewBuffer
function M.new(commits, internal_args, files, fetch_func, header, remotes)
  local instance = {
    files = files,
    commits = commits,
    remotes = remotes,
    internal_args = internal_args,
    fetch_func = fetch_func,
    buffer = nil,
    refresh_lock = a.control.Semaphore.new(1),
    header = header,
  }

  setmetatable(instance, M)

  return instance
end

function M:commit_count()
  return #util.filter_map(self.commits, function(commit)
    if commit.oid then
      return 1
    end
  end)
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

function M:open()
  if M.is_open() then
    M.instance.buffer:focus()
    return
  end

  M.instance = self

  self.buffer = Buffer.create {
    name = "NeogitLogView",
    filetype = "NeogitLogView",
    kind = config.values.log_view.kind,
    context_highlight = false,
    header = self.header,
    scroll_header = false,
    active_item_highlight = true,
    status_column = not config.values.disable_signs and "" or nil,
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
        [popups.mapping_for("RemotePopup")] = popups.open("remote"),
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
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          local items = self.buffer.ui:get_commits_in_selection()
          p {
            section = { name = "log" },
            item = { name = items },
          }
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
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          local item = self.buffer.ui:get_commit_under_cursor()
          p {
            section = { name = "log" },
            item = { name = item },
          }
        end),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
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
            CommitViewBuffer.new(commit, self.files):open()
          end
        end,
        [status_maps["PeekFile"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            CommitViewBuffer.new(commit, self.files):open()
            self.buffer:focus()
          end
        end,
        [status_maps["OpenOrScrollDown"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            CommitViewBuffer.open_or_scroll_down(commit, self.files)
          end
        end,
        [status_maps["OpenOrScrollUp"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            CommitViewBuffer.open_or_scroll_up(commit, self.files)
          end
        end,
        [status_maps["PeekUp"]] = function()
          -- Open prev fold
          pcall(vim.cmd, "normal! zc")

          vim.cmd("normal! k")
          for _ = vim.fn.line("."), 0, -1 do
            if vim.fn.foldlevel(".") > 0 then
              break
            end

            vim.cmd("normal! k")
          end

          if CommitViewBuffer.is_open() then
            local commit = self.buffer.ui:get_commit_under_cursor()
            if commit then
              CommitViewBuffer.instance:update(commit, self.files)
            end
          else
            pcall(vim.cmd, "normal! zo")
            vim.cmd("normal! zz")
          end
        end,
        [status_maps["PeekDown"]] = function()
          pcall(vim.cmd, "normal! zc")

          vim.cmd("normal! j")
          for _ = vim.fn.line("."), vim.fn.line("$"), 1 do
            if vim.fn.foldlevel(".") > 0 then
              break
            end

            vim.cmd("normal! j")
          end

          if CommitViewBuffer.is_open() then
            local commit = self.buffer.ui:get_commit_under_cursor()
            if commit then
              CommitViewBuffer.instance:update(commit, self.files)
            end
          else
            pcall(vim.cmd, "normal! zo")
            vim.cmd("normal! zz")
          end
        end,
        ["+"] = a.void(function()
          local permit = self.refresh_lock:acquire()

          self.commits = util.merge(self.commits, self.fetch_func(self:commit_count()))
          self.buffer.ui:render(unpack(ui.View(self.commits, self.remotes, self.internal_args)))

          permit:forget()
        end),
        ["<tab>"] = function()
          pcall(vim.cmd, "normal! za")
        end,
        ["j"] = function()
          if vim.v.count > 0 then
            vim.cmd("norm! " .. vim.v.count .. "j")
          else
            vim.cmd("norm! j")
          end

          while self.buffer:get_current_line()[1]:sub(1, 1) == " " do
            if vim.fn.line(".") == vim.fn.line("$") then
              break
            end

            vim.cmd("norm! j")
          end
        end,
        ["k"] = function()
          if vim.v.count > 0 then
            vim.cmd("norm! " .. vim.v.count .. "k")
          else
            vim.cmd("norm! k")
          end

          while self.buffer:get_current_line()[1]:sub(1, 1) == " " do
            if vim.fn.line(".") == 1 then
              break
            end

            vim.cmd("norm! k")
          end
        end,
      },
    },
    render = function()
      return ui.View(self.commits, self.remotes, self.internal_args)
    end,
    after = function(buffer)
      -- First line is empty, so move cursor to second line.
      buffer:move_cursor(2)
    end,
  }
end

return M
