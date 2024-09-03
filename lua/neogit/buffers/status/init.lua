local config = require("neogit.config")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.status.ui")
local popups = require("neogit.popups")
local git = require("neogit.lib.git")
local Watcher = require("neogit.watcher")
local a = require("plenary.async")
local logger = require("neogit.logger") -- TODO: Add logging

local api = vim.api

---@class Semaphore
---@field permits number
---@field acquire function

---@class StatusBuffer
---@field buffer Buffer instance
---@field config NeogitConfig
---@field root string
local M = {}
M.__index = M

local instances = {}

---@param instance StatusBuffer
---@param dir string
function M.register(instance, dir)
  local dir = vim.fs.normalize(dir)
  logger.debug("[STATUS] Registering instance for: " .. dir)

  instances[dir] = instance
end

---@param dir? string
---@return StatusBuffer
function M.instance(dir)
  local dir = dir or vim.uv.cwd()
  assert(dir, "cannot locate a status buffer with no cwd")

  return instances[vim.fs.normalize(dir)]
end

---@param config NeogitConfig
---@param root string
---@return StatusBuffer
function M.new(config, root)
  local instance = {
    config = config,
    root = root,
    buffer = nil,
  }

  setmetatable(instance, M)

  return instance
end

---@return boolean
function M.is_open()
  return (M.instance() and M.instance().buffer and M.instance().buffer:is_visible()) == true
end

function M:_action(name)
  local action = require("neogit.buffers.status.actions")[name]
  assert(action, ("Status Buffer action %q is undefined"):format(name))

  return action(self)
end

---@param kind string<"floating" | "split" | "tab" | "split" | "vsplit">|nil
---@param cwd string
---@return StatusBuffer
function M:open(kind, cwd)
  if M.is_open() then
    logger.debug("[STATUS] An Instance is already open - focusing it")
    M.instance():focus()
    return M.instance()
  end

  M.register(self, cwd)

  local mappings = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitStatus",
    filetype = "NeogitStatus",
    cwd = cwd,
    context_highlight = not config.values.disable_context_highlighting,
    kind = kind or config.values.kind,
    disable_line_numbers = config.values.disable_line_numbers,
    foldmarkers = not config.values.disable_signs,
    on_detach = function()
      Watcher.instance(self.root):unregister(self)
      vim.o.autochdir = self.prev_autochdir
    end,
    --stylua: ignore start
    mappings = {
      v = {
        [mappings["Discard"]]                   = self:_action("v_discard"),
        [mappings["Stage"]]                     = self:_action("v_stage"),
        [mappings["Unstage"]]                   = self:_action("v_unstage"),
        [mappings["Untrack"]]                   = self:_action("v_untrack"),
        [popups.mapping_for("BisectPopup")]     = self:_action("v_bisect_popup"),
        [popups.mapping_for("BranchPopup")]     = self:_action("v_branch_popup"),
        [popups.mapping_for("CherryPickPopup")] = self:_action("v_cherry_pick_popup"),
        [popups.mapping_for("CommitPopup")]     = self:_action("v_commit_popup"),
        [popups.mapping_for("DiffPopup")]       = self:_action("v_diff_popup"),
        [popups.mapping_for("FetchPopup")]      = self:_action("v_fetch_popup"),
        [popups.mapping_for("HelpPopup")]       = self:_action("v_help_popup"),
        [popups.mapping_for("IgnorePopup")]     = self:_action("v_ignore_popup"),
        [popups.mapping_for("LogPopup")]        = self:_action("v_log_popup"),
        [popups.mapping_for("MergePopup")]      = self:_action("v_merge_popup"),
        [popups.mapping_for("PullPopup")]       = self:_action("v_pull_popup"),
        [popups.mapping_for("PushPopup")]       = self:_action("v_push_popup"),
        [popups.mapping_for("RebasePopup")]     = self:_action("v_rebase_popup"),
        [popups.mapping_for("RemotePopup")]     = self:_action("v_remote_popup"),
        [popups.mapping_for("ResetPopup")]      = self:_action("v_reset_popup"),
        [popups.mapping_for("RevertPopup")]     = self:_action("v_revert_popup"),
        [popups.mapping_for("StashPopup")]      = self:_action("v_stash_popup"),
        [popups.mapping_for("TagPopup")]        = self:_action("v_tag_popup"),
        [popups.mapping_for("WorktreePopup")]   = self:_action("v_worktree_popup"),
      },
      n = {
        [mappings["OpenTree"]]                  = self:_action("n_open_tree"),
        [mappings["MoveDown"]]                  = self:_action("n_down"),
        [mappings["MoveUp"]]                    = self:_action("n_up"),
        [mappings["Untrack"]]                   = self:_action("n_untrack"),
        [mappings["Toggle"]]                    = self:_action("n_toggle"),
        [mappings["Close"]]                     = self:_action("n_close"),
        [mappings["OpenOrScrollDown"]]          = self:_action("n_open_or_scroll_down"),
        [mappings["OpenOrScrollUp"]]            = self:_action("n_open_or_scroll_up"),
        [mappings["RefreshBuffer"]]             = self:_action("n_refresh_buffer"),
        [mappings["Depth1"]]                    = self:_action("n_depth1"),
        [mappings["Depth2"]]                    = self:_action("n_depth2"),
        [mappings["Depth3"]]                    = self:_action("n_depth3"),
        [mappings["Depth4"]]                    = self:_action("n_depth4"),
        [mappings["CommandHistory"]]            = self:_action("n_command_history"),
        [mappings["ShowRefs"]]                  = self:_action("n_show_refs"),
        [mappings["YankSelected"]]              = self:_action("n_yank_selected"),
        [mappings["Discard"]]                   = self:_action("n_discard"),
        [mappings["GoToNextHunkHeader"]]        = self:_action("n_go_to_next_hunk_header"),
        [mappings["GoToPreviousHunkHeader"]]    = self:_action("n_go_to_previous_hunk_header"),
        [mappings["InitRepo"]]                  = self:_action("n_init_repo"),
        [mappings["Stage"]]                     = self:_action("n_stage"),
        [mappings["StageAll"]]                  = self:_action("n_stage_all"),
        [mappings["StageUnstaged"]]             = self:_action("n_stage_unstaged"),
        [mappings["Unstage"]]                   = self:_action("n_unstage"),
        [mappings["UnstageStaged"]]             = self:_action("n_unstage_staged"),
        [mappings["GoToFile"]]                  = self:_action("n_goto_file"),
        [mappings["TabOpen"]]                   = self:_action("n_tab_open"),
        [mappings["SplitOpen"]]                 = self:_action("n_split_open"),
        [mappings["VSplitOpen"]]                = self:_action("n_vertical_split_open"),
        [popups.mapping_for("BisectPopup")]     = self:_action("n_bisect_popup"),
        [popups.mapping_for("BranchPopup")]     = self:_action("n_branch_popup"),
        [popups.mapping_for("CherryPickPopup")] = self:_action("n_cherry_pick_popup"),
        [popups.mapping_for("CommitPopup")]     = self:_action("n_commit_popup"),
        [popups.mapping_for("DiffPopup")]       = self:_action("n_diff_popup"),
        [popups.mapping_for("FetchPopup")]      = self:_action("n_fetch_popup"),
        [popups.mapping_for("HelpPopup")]       = self:_action("n_help_popup"),
        [popups.mapping_for("IgnorePopup")]     = self:_action("n_ignore_popup"),
        [popups.mapping_for("LogPopup")]        = self:_action("n_log_popup"),
        [popups.mapping_for("MergePopup")]      = self:_action("n_merge_popup"),
        [popups.mapping_for("PullPopup")]       = self:_action("n_pull_popup"),
        [popups.mapping_for("PushPopup")]       = self:_action("n_push_popup"),
        [popups.mapping_for("RebasePopup")]     = self:_action("n_rebase_popup"),
        [popups.mapping_for("RemotePopup")]     = self:_action("n_remote_popup"),
        [popups.mapping_for("ResetPopup")]      = self:_action("n_reset_popup"),
        [popups.mapping_for("RevertPopup")]     = self:_action("n_revert_popup"),
        [popups.mapping_for("StashPopup")]      = self:_action("n_stash_popup"),
        [popups.mapping_for("TagPopup")]        = self:_action("n_tag_popup"),
        [popups.mapping_for("WorktreePopup")]   = self:_action("n_worktree_popup"),
      },
    },
    --stylua: ignore end
    user_mappings = config.get_user_mappings("status"),
    initialize = function()
      self.prev_autochdir = vim.o.autochdir
      vim.o.autochdir = false
    end,
    render = function()
      if git.repo.state.initialized then
        return ui.Status(git.repo.state, self.config)
      else
        return {}
      end
    end,
    ---@param buffer Buffer
    ---@param _win any
    after = function(buffer, _win)
      Watcher.instance(self.root):register(self)
      buffer:move_cursor(buffer.ui:first_section().first)
    end,
    autocmds = {
      ["FocusGained"] = function()
        self:dispatch_refresh(nil, "focus_gained")
      end,
    },
    user_autocmds = {
      ["NeogitPushComplete"] = function()
        self:dispatch_refresh(nil, "push_complete")
      end,
      ["NeogitPullComplete"] = function()
        self:dispatch_refresh(nil, "pull_complete")
      end,
      ["NeogitFetchComplete"] = function()
        self:dispatch_refresh(nil, "fetch_complete")
      end,
      ["NeogitRebase"] = function()
        self:dispatch_refresh(nil, "rebase")
      end,
      ["NeogitMerge"] = function()
        self:dispatch_refresh(nil, "merge")
      end,
      ["NeogitReset"] = function()
        self:dispatch_refresh(nil, "reset_complete")
      end,
      ["NeogitStash"] = function()
        self:dispatch_refresh(nil, "stash")
      end,
    },
  }

  return self
end

function M:close()
  if self.buffer then
    logger.debug("[STATUS] Closing Buffer")
    self.buffer:close()
    self.buffer = nil
  end

  Watcher.instance(self.root):unregister(self)
  if self.prev_autochdir then
    vim.o.autochdir = self.prev_autochdir
  end
end

function M:chdir(dir)
  local destination = require("plenary.path").new(dir)
  vim.wait(5000, function()
    return destination:exists()
  end)

  logger.debug("[STATUS] Changing Dir: " .. dir)
  vim.api.nvim_set_current_dir(dir)
  self:dispatch_reset()
end

function M:focus()
  if self.buffer then
    logger.debug("[STATUS] Focusing Buffer")
    self.buffer:focus()
  end
end

function M:refresh(partial, reason)
  logger.debug("[STATUS] Beginning refresh from " .. (reason or "UNKNOWN"))

  local cursor, view
  if self.buffer and self.buffer:is_focused() then
    cursor = self.buffer.ui:get_cursor_location()
    view = self.buffer:save_view()
  end

  git.repo:dispatch_refresh {
    source = "status/" .. (reason or "UNKNOWN"),
    partial = partial,
    callback = function()
      self:redraw(cursor, view)
      api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed", modeline = false })
      logger.info("[STATUS] Refresh complete")
    end,
  }
end

---@param cursor CursorLocation?
---@param view table?
function M:redraw(cursor, view)
  if not self.buffer then
    logger.debug("[STATUS] Buffer no longer exists - bail")
    return
  end

  logger.debug("[STATUS] Rendering UI")
  self.buffer.ui:render(unpack(ui.Status(git.repo.state, self.config)))

  if cursor and view and self.buffer:is_focused() then
    self.buffer:restore_view(view, self.buffer.ui:resolve_cursor_location(cursor))
  end
end

M.dispatch_refresh = a.void(function(self, partial, reason)
  self:refresh(partial, reason)
end)

function M:reset()
  logger.debug("[STATUS] Resetting repo and refreshing")
  git.repo:reset()
  self:refresh(nil, "reset")
end

M.dispatch_reset = a.void(function(self)
  self:reset()
end)

function M:id()
  return "StatusBuffer"
end

return M
