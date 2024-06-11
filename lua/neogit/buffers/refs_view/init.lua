local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local ui = require("neogit.buffers.refs_view.ui")
local popups = require("neogit.popups")
local status_maps = require("neogit.config").get_reversed_status_maps()
local CommitViewBuffer = require("neogit.buffers.commit_view")
local Watcher = require("neogit.watcher")
local logger = require("neogit.logger")
local a = require("plenary.async")
local git = require("neogit.lib.git")

--- @class RefsViewBuffer
--- @field buffer Buffer
--- @field open fun()
--- @field close fun()
--- @see RefsInfo
--- @see Buffer
--- @see Ui
local M = {
  instance = nil,
}

--- Creates a new RefsViewBuffer
--- @return RefsViewBuffer
function M.new(refs, root)
  local instance = {
    refs = refs,
    root = root,
    head = "HEAD",
    buffer = nil,
    watcher = nil,
    last_refreshed = 0,
  }

  setmetatable(instance, { __index = M })
  return instance
end

function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end

  if self.watcher then
    logger.debug("[REFS] Stopping Watcher")
    self.watcher:stop()
  end

  M.instance = nil
end

---@return boolean
function M.is_open()
  return (M.instance and M.instance.buffer and M.instance.buffer:is_visible()) == true
end

--- Opens the RefsViewBuffer
function M:open()
  if M.is_open() then
    M.instance.buffer:focus()
    return
  end

  M.instance = self

  self.buffer = Buffer.create {
    name = "NeogitRefsView",
    filetype = "NeogitRefsView",
    kind = config.values.refs_view.kind,
    context_highlight = false,
    on_detach = function()
      if self.watcher then
        self.watcher:stop()
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
      },
    },
    render = function()
      return ui.RefsView(self.refs, self.head)
    end,
    ---@param buffer Buffer
    ---@param _win any
    after = function(buffer, _win)
      if config.values.filewatcher.enabled then
        logger.debug("[REFS] Starting file watcher")
        self.watcher = Watcher.new(self, self.root):start()
      end

      buffer:move_cursor(buffer.ui:first_section().first)
    end,
  }
end

M.dispatch_refresh = a.void(function(self, partial, reason)
  local now = vim.uv.now()
  local delta_t = now - self.last_refreshed
  if reason == "watcher" and delta_t < 250 then
    logger.debug("[REFS] Refreshed within last 250ms - skipping watcher (dt: " .. delta_t .. " ms)")
  else
    self:refresh(partial, reason)
  end
end)

function M:refresh(partial, reason)
  logger.debug("[REFS] Beginning refresh from " .. (reason or "UNKNOWN"))

  vim.uv.update_time()
  local start = vim.loop.now()

  local cursor, view
  if self.buffer and self.buffer:is_focused() then
    cursor = self.buffer.ui:get_cursor_location()
    view = self.buffer:save_view()
  end

  git.repo:refresh {
    source = "refs",
    partial = partial,
    callback = function()
      if not self.buffer then
        logger.debug("[REFS][Refresh Callback] Buffer no longer exists - bail")
        return
      end

      logger.debug("[REFS][Refresh Callback] Rendering UI")
      self.buffer.ui:render(unpack(ui.RefsView(git.refs.list_parsed(), self.head)))

      if cursor and view then
        self.buffer:restore_view(view, self.buffer.ui:resolve_cursor_location(cursor))
      end

      vim.api.nvim_exec_autocmds("User", { pattern = "NeogitRefsRefreshed", modeline = false })

      vim.uv.update_time()
      local now = vim.uv.now()
      logger.info("[REFS][Refresh Callback] Refreshed in " .. now - start .. " ms")
      self.last_refreshed = now
    end,
  }
end

return M
