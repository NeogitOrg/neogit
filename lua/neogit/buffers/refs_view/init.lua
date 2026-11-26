local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local ui = require("neogit.buffers.refs_view.ui")
local popups = require("neogit.popups")
local mapping = config.get_reversed_refs_view_maps()
local CommitViewBuffer = require("neogit.buffers.commit_view")
local Watcher = require("neogit.watcher")
local logger = require("neogit.logger")
local a = require("neogit.lib.async")
local git = require("neogit.lib.git")
local event = require("neogit.lib.event")

---@class RefsViewBuffer
---@field buffer Buffer
---@field open fun()
---@field close fun()
---@see RefsInfo
---@see Buffer
---@see Ui
local M = {
  instance = nil,
}

---Creates a new RefsViewBuffer
---@return RefsViewBuffer
function M.new(refs, root)
  local instance = {
    refs = refs,
    root = root,
    head = "HEAD",
    buffer = nil,
  }

  setmetatable(instance, { __index = M })
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
    Watcher.instance(self.root):unregister(self)
    M.instance = nil
  end
end

---@return boolean
function M.is_open()
  return Buffer.is_open(M.instance)
end

function M._do_delete(ref)
  if not ref.remote then
    git.branch.delete(ref.unambiguous_name)
  else
    git.cli.push.remote(ref.remote).delete.to(ref.name).call()
  end
end

function M.delete_branch(ref)
  if ref then
    local input = require("neogit.lib.input")
    local message = ("Delete branch: '%s'?"):format(ref.unambiguous_name)
    if input.get_permission(message) then
      M._do_delete(ref)
    end
  end
end

function M.delete_branches(refs)
  if #refs > 0 then
    local input = require("neogit.lib.input")
    local message = ("Delete %s branch(es)?"):format(#refs)
    if input.get_permission(message) then
      for _, ref in ipairs(refs) do
        M._do_delete(ref)
      end
    end
  end
end

--- Opens the RefsViewBuffer
function M:open()
  if M.is_open() then
    M.instance.buffer:focus()
    return
  end

  M.instance = self
  local status_maps = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitRefsView",
    filetype = "NeogitRefsView",
    kind = config.values.refs_view.kind,
    bufhidden = config.values.keep_hidden_buffers and "hide" or nil,
    buflisted = config.values.keep_hidden_buffers or nil,
    context_highlight = false,
    on_detach = function()
      Watcher.instance(self.root):unregister(self)
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

      a.void(function()
        self:redraw()
      end)()
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
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RemotePopup")] = popups.open("remote", function(p)
          p()
          -- p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          local items = self.buffer.ui:get_ordered_commits_in_selection()
          p {
            section = { name = "log" },
            item = { name = items },
          }
        end),
        [mapping["DeleteBranch"]] = function()
          M.delete_branches(self.buffer.ui:get_refs_under_cursor())
          self:redraw()
        end,
      },
      n = {
        [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          local ref = self.buffer.ui:get_ref_under_cursor()
          p {
            ref_name = ref and ref.unambiguous_name,
            commits = self.buffer.ui:get_commits_in_selection(),
            suggested_branch_name = ref and ref.name,
          }
        end),
        [mapping["DeleteBranch"]] = function()
          M.delete_branch(self.buffer.ui:get_ref_under_cursor())
          self:redraw()
        end,
        [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("RemotePopup")] = popups.open("remote", function(p)
          p()
          -- p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          p { commit = self.buffer.ui:get_commits_in_selection()[1] }
        end),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          local item = self.buffer.ui:get_commit_under_cursor()
          p {
            section = { name = "log" },
            item = { name = item },
          }
        end),
        ["j"] = function()
          if vim.v.count > 0 then
            vim.cmd("norm! " .. vim.v.count .. "j")
          else
            vim.cmd("norm! j")
          end

          if self.buffer:get_current_line()[1] == "  " then
            vim.cmd("norm! j")
          end
        end,
        ["k"] = function()
          if vim.v.count > 0 then
            vim.cmd("norm! " .. vim.v.count .. "k")
          else
            vim.cmd("norm! k")
          end

          if self.buffer:get_current_line()[1] == "  " then
            vim.cmd("norm! k")
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
        -- ["{"] = function()
        --   pcall(vim.cmd, "normal! zc")
        --
        --   vim.cmd("normal! k")
        --   for _ = vim.fn.line("."), 0, -1 do
        --     if vim.fn.foldlevel(".") > 0 then
        --       break
        --     end
        --
        --     vim.cmd("normal! k")
        --   end
        --
        --   pcall(vim.cmd, "normal! zo")
        --   vim.cmd("normal! zz")
        -- end,
        -- ["}"] = function()
        --   pcall(vim.cmd, "normal! zc")
        --
        --   vim.cmd("normal! j")
        --   for _ = vim.fn.line("."), vim.fn.line("$"), 1 do
        --     if vim.fn.foldlevel(".") > 0 then
        --       break
        --     end
        --
        --     vim.cmd("normal! j")
        --   end
        --
        --   pcall(vim.cmd, "normal! zo")
        --   vim.cmd("normal! zz")
        -- end,
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
        [status_maps["RefreshBuffer"]] = a.void(function()
          self:redraw()
        end),
      },
    },
    render = function()
      return ui.RefsView(self.refs, self.head)
    end,
    ---@param buffer Buffer
    ---@param _win any
    after = function(buffer, _win)
      Watcher.instance(self.root):register(self)
      buffer:move_cursor(buffer.ui:first_section().first)
    end,
  }
end

function M:redraw()
  if not self.buffer or not self.buffer:is_valid() or not self.buffer:is_visible() then
    return
  end

  logger.debug("[REFS] Beginning redraw")
  local fold_state = self.buffer.ui:get_fold_state()
  local cursor, view
  self.buffer:win_call(function()
    cursor = self.buffer:cursor_line()
    view = self.buffer:save_view()
  end)

  self.refs = git.refs.list_parsed()
  self.buffer.ui:render(unpack(ui.RefsView(self.refs, self.head)))
  self.buffer.ui:set_fold_state(fold_state)

  if self.buffer and self.buffer:is_visible() and view and cursor then
    self.buffer:win_call(function()
      self.buffer:restore_view(view, cursor)
    end)
  end

  event.send("RefsRefreshed")
  logger.info("[REFS] Redraw complete")
end

function M:id()
  return "RefsViewBuffer"
end

return M
