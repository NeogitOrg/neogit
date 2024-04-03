-- TODO: When launching the fuzzy finder, any refresh attempted will raise an exception because the set_folds() function
-- cannot be called when the buffer is not focused, as it's not a proper API. We could implement some kind of freeze
-- mechanism to prevent the buffer from refreshing while the fuzzy finder is open.
-- function M:freeze()
--   self.frozen = true
-- end
--
-- function M:unfreeze()
--   self.frozen = false
-- end

local config = require("neogit.config")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.status.ui")
local popups = require("neogit.popups")
local git = require("neogit.lib.git")
local Watcher = require("neogit.watcher")
local a = require("plenary.async")
local input = require("neogit.lib.input")
local logger = require("neogit.logger") -- TODO: Add logging
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")

local api = vim.api
local fn = vim.fn

---@class Semaphore
---@field permits number
---@field acquire function

---@class StatusBuffer
---@field buffer Buffer instance
---@field state NeogitRepo
---@field config NeogitConfig
---@field frozen boolean
---@field refresh_lock Semaphore
local M = {}
M.__index = M

local instances = {}

function M.register(instance, dir)
  instances[dir] = instance
end

function M.unregister()
  instances[vim.uv.cwd()] = nil
end

function M.instance()
  return instances[vim.uv.cwd()]
end

---@param state NeogitRepo
---@param config NeogitConfig
---@param root string
---@return StatusBuffer
function M.new(state, config, root)
  local instance = {
    -- frozen = false,
    state = state,
    config = config,
    root = root,
    buffer = nil,
    watcher = nil,
    refresh_lock = a.control.Semaphore.new(1),
  }

  setmetatable(instance, M)

  return instance
end

---@return boolean
function M.is_open()
  return (M.instance() and M.instance().buffer and M.instance().buffer:is_visible()) == true
end

---@param kind string<"floating" | "split" | "tab" | "split" | "vsplit">|nil
---@param cwd string
function M:open(kind, cwd)
  if M.is_open() then
    logger.debug("[STATUS] An Instance is already open - closing it")
    M.instance():close()
  end

  M.register(self, cwd)

  local mappings = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitStatus",
    filetype = "NeogitStatus",
    context_highlight = true,
    kind = kind or config.values.kind,
    disable_line_numbers = config.values.disable_line_numbers,
    status_column = " ",
    on_detach = function()
      if self.watcher then
        self.watcher:stop()
      end

      vim.o.autochdir = self.prev_autochdir
      M.unregister()
    end,
    autocmds = {
      ["BufEnter"] = function()
        self:dispatch_refresh()
      end,
    },
    mappings = {
      v = {
        [mappings["Discard"]] = a.void(function()
          local selection = self.buffer.ui:get_selection()

          local discard_message = "Discard selection?"
          local hunk_count = 0
          local file_count = 0

          local patches = {}
          local untracked_files = {}
          local unstaged_files = {}
          local new_files = {}
          local staged_files_modified = {}
          local stashes = {}

          for _, section in ipairs(selection.sections) do
            if section.name == "untracked" or section.name == "unstaged" or section.name == "staged" then
              file_count = file_count + #section.items

              for _, item in ipairs(section.items) do
                local hunks = self.buffer.ui:item_hunks(item, selection.first_line, selection.last_line, true)

                if #hunks > 0 then
                  logger.fmt_debug("Discarding %d hunks from %q", #hunks, item.name)

                  hunk_count = hunk_count + #hunks
                  if hunk_count > 1 then
                    discard_message = ("Discard %s hunks?"):format(hunk_count)
                  end

                  for _, hunk in ipairs(hunks) do
                    table.insert(patches, function()
                      local patch = git.index.generate_patch(item, hunk, hunk.from, hunk.to, true)

                      logger.fmt_debug("Discarding Patch: %s", patch)

                      git.index.apply(patch, {
                        index = section.name == "staged",
                        reverse = true,
                      })
                    end)
                  end
                else
                  discard_message = ("Discard %s files?"):format(file_count)
                  logger.fmt_debug("Discarding in section %s %s", section.name, item.name)

                  if section.name == "untracked" then
                    table.insert(untracked_files, item.escaped_path)
                  elseif section.name == "unstaged" then
                    if selection.item.mode == "A" then
                      table.insert(new_files, item.escaped_path)
                    else
                      table.insert(unstaged_files, item.escaped_path)
                    end
                  elseif section.name == "staged" then
                    if item.mode == "N" then
                      table.insert(new_files, item.escaped_path)
                    else
                      table.insert(staged_files_modified, item.escaped_path)
                    end
                  end
                end
              end
            elseif section.name == "stashes" then
              discard_message = ("Discard %s stashes?"):format(#selection.items)

              for _, stash in ipairs(selection.items) do
                table.insert(stashes, stash.name:match("(stash@{%d+})"))
              end
            end
          end

          if input.get_permission(discard_message) then
            if #patches > 0 then
              for _, patch in ipairs(patches) do
                patch()
              end
            end

            if #untracked_files > 0 then
              a.util.scheduler()

              for _, file in ipairs(untracked_files) do
                local bufnr = fn.bufexists(file.name)
                if bufnr and bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
                  api.nvim_buf_delete(bufnr, { force = true })
                end

                fn.delete(file.escaped_path)
              end
            end

            if #unstaged_files > 0 then
              git.index.checkout(unstaged_files)
            end

            if #new_files > 0 then
              git.index.reset(new_files)

              a.util.scheduler()

              for _, file in ipairs(new_files) do
                local bufnr = fn.bufexists(file.name)
                if bufnr and bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
                  api.nvim_buf_delete(bufnr, { force = true })
                end

                fn.delete(file.escaped_path)
              end
            end

            if #staged_files_modified > 0 then
              git.index.reset(staged_files_modified)
              git.index.checkout(staged_files_modified)
            end

            if #stashes > 0 then
              for _, stash in ipairs(stashes) do
                git.stash.drop(stash)
              end
            end

            self:refresh()
          end
        end),
        [mappings["Stage"]] = a.void(function()
          local selection = self.buffer.ui:get_selection()

          local untracked_files = {}
          local unstaged_files = {}
          local patches = {}

          for _, section in ipairs(selection.sections) do
            if section.name == "unstaged" or section.name == "untracked" then
              for _, item in ipairs(section.items) do
                local hunks = self.buffer.ui:item_hunks(item, selection.first_line, selection.last_line, true)

                if #hunks > 0 then
                  for _, hunk in ipairs(hunks) do
                    table.insert(patches, git.index.generate_patch(item, hunk, hunk.from, hunk.to))
                  end
                else
                  if section.name == "unstaged" then
                    table.insert(unstaged_files, item.escaped_path)
                  else
                    table.insert(untracked_files, item.escaped_path)
                  end
                end
              end
            end
          end

          if #untracked_files > 0 then
            git.index.add(untracked_files)
          end

          if #unstaged_files > 0 then
            git.status.stage(unstaged_files)
          end

          if #patches > 0 then
            for _, patch in ipairs(patches) do
              git.index.apply(patch, { cached = true })
            end
          end

          if #untracked_files > 0 or #unstaged_files > 0 or #patches > 0 then
            self:refresh()
          end
        end),
        [mappings["Unstage"]] = a.void(function()
          local selection = self.buffer.ui:get_selection()

          local files = {}
          local patches = {}

          for _, section in ipairs(selection.sections) do
            if section.name == "staged" then
              for _, item in ipairs(section.items) do
                local hunks = self.buffer.ui:item_hunks(item, selection.first_line, selection.last_line, true)

                if #hunks > 0 then
                  for _, hunk in ipairs(hunks) do
                    table.insert(patches, git.index.generate_patch(item, hunk, hunk.from, hunk.to))
                  end
                else
                  table.insert(files, item.escaped_path)
                end
              end
            end
          end

          if #files > 0 then
            git.status.unstage(files)
          end

          if #patches > 0 then
            for _, patch in ipairs(patches) do
              git.index.apply(patch, { cached = true, reverse = true })
            end
          end

          if #files > 0 or #patches > 0 then
            self:refresh()
          end
        end),
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
          local commits = self.buffer.ui:get_commits_in_selection()
          if #commits == 1 then
            p { commit = commits[1] }
          end
        end),
        [popups.mapping_for("MergePopup")] = popups.open("merge", function(p)
          local commits = self.buffer.ui:get_commits_in_selection()
          if #commits == 1 then
            p { commit = commits[1] }
          end
        end),
        [popups.mapping_for("PushPopup")] = popups.open("push", function(p)
          local commits = self.buffer.ui:get_commits_in_selection()
          if #commits == 1 then
            p { commit = commits[1] }
          end
        end),
        [popups.mapping_for("RebasePopup")] = popups.open("rebase", function(p)
          local commits = self.buffer.ui:get_commits_in_selection()
          if #commits == 1 then
            p { commit = commits[1] }
          end
        end),
        [popups.mapping_for("RevertPopup")] = popups.open("revert", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          local commits = self.buffer.ui:get_commits_in_selection()
          if #commits == 1 then
            p { commit = commits[1] }
          end
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          local commits = self.buffer.ui:get_commits_in_selection()
          if #commits == 1 then
            p { commit = commits[1] }
          end
        end),
        [popups.mapping_for("StashPopup")] = popups.open("stash", function(p)
          local stash = self.buffer.ui:get_yankable_under_cursor()
          p { name = stash and stash:match("^stash@{%d+}") }
        end),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          local section = self.buffer.ui:get_selection().sections[1]
          local item = self.buffer.ui:get_yankable_under_cursor()
          p { section = { name = section }, item = { name = item } }
        end),
        [popups.mapping_for("IgnorePopup")] = popups.open("ignore", function(p)
          p { paths = self.buffer.ui:get_filepaths_in_selection(), git_root = git.repo.git_root }
        end),
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
          p { commits = self.buffer.ui:get_commits_in_selection() }
        end),
        [popups.mapping_for("RemotePopup")] = popups.open("remote"),
        [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        [popups.mapping_for("HelpPopup")] = popups.open("help"),
        [popups.mapping_for("LogPopup")] = popups.open("log"),
        [popups.mapping_for("WorktreePopup")] = popups.open("worktree"),
      },
      n = {
        [mappings["Toggle"]] = function()
          local fold = self.buffer.ui:get_fold_under_cursor()
          if fold then
            -- Do not allow folding on the last (empty) line of a section. It should be considered "not part of either
            -- section" from a UX perspective. Only applies to unfolded sections.
            if
              fold.options.tag == "Section"
              and not fold.options.folded
              and self.buffer:get_current_line()[1] == ""
            then
              logger.info("Toggle early return")
              return
            end

            if fold.options.on_open then
              fold.options.on_open(fold, self.buffer.ui)
            else
              local start, _ = fold:row_range_abs()
              local ok, _ = pcall(vim.cmd, "normal! za")
              if ok then
                self.buffer:move_cursor(start)
                fold.options.folded = not fold.options.folded
              end
            end
          end
        end,
        [mappings["Close"]] = require("neogit.lib.ui.helpers").close_topmost(self),
        [mappings["OpenOrScrollDown"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            require("neogit.buffers.commit_view").open_or_scroll_down(commit)
          end
        end,
        [mappings["OpenOrScrollUp"]] = function()
          local commit = self.buffer.ui:get_commit_under_cursor()
          if commit then
            require("neogit.buffers.commit_view").open_or_scroll_up(commit)
          end
        end,
        [mappings["RefreshBuffer"]] = a.void(function()
          self:refresh()
        end),
        [mappings["Depth1"]] = function()
          local section = self.buffer.ui:get_current_section()
          if section then
            local start, _ = section:row_range_abs()
            self.buffer:move_cursor(start)
            section:close_all_folds(self.buffer.ui)

            self.buffer.ui:update()
          end
        end,
        [mappings["Depth2"]] = function()
          local section = self.buffer.ui:get_current_section()
          local row = self.buffer.ui:get_component_under_cursor()

          if section then
            local start, _ = section:row_range_abs()
            self.buffer:move_cursor(start)

            section:close_all_folds(self.buffer.ui)
            section:open_all_folds(self.buffer.ui, 1)

            self.buffer.ui:update()

            if row then
              local start, _ = row:row_range_abs()
              self.buffer:move_cursor(start)
            end
          end
        end,
        [mappings["Depth3"]] = function()
          local section = self.buffer.ui:get_current_section()
          local context = self.buffer.ui:get_cursor_context()

          if section then
            local start, _ = section:row_range_abs()
            self.buffer:move_cursor(start)

            section:close_all_folds(self.buffer.ui)
            section:open_all_folds(self.buffer.ui, 2)
            section:close_all_folds(self.buffer.ui)
            section:open_all_folds(self.buffer.ui, 2)

            self.buffer.ui:update()

            if context then
              local start, _ = context:row_range_abs()
              self.buffer:move_cursor(start)
            end
          end
        end,
        [mappings["Depth4"]] = function()
          local section = self.buffer.ui:get_current_section()
          local context = self.buffer.ui:get_cursor_context()

          if section then
            local start, _ = section:row_range_abs()
            self.buffer:move_cursor(start)
            section:close_all_folds(self.buffer.ui)
            section:open_all_folds(self.buffer.ui, 3)

            self.buffer.ui:update()

            if context then
              local start, _ = context:row_range_abs()
              self.buffer:move_cursor(start)
            end
          end
        end,
        [mappings["CommandHistory"]] = a.void(function()
          require("neogit.buffers.git_command_history"):new():show()
        end),
        [mappings["Console"]] = function()
          require("neogit.process").show_console()
        end,
        [mappings["ShowRefs"]] = a.void(function()
          require("neogit.buffers.refs_view").new(git.refs.list_parsed()):open()
        end),
        [mappings["YankSelected"]] = function()
          local yank = self.buffer.ui:get_yankable_under_cursor()
          if yank then
            if yank:match("^stash@{%d+}") then
              yank = git.rev_parse.oid(yank:match("^(stash@{%d+})"))
            end

            yank = string.format("'%s'", yank)
            vim.cmd.let("@+=" .. yank)
            vim.cmd.echo(yank)
          else
            vim.cmd("echo ''")
          end
        end,
        [mappings["Discard"]] = a.void(function()
          git.index.update()

          local selection = self.buffer.ui:get_selection()
          if not selection.section then
            return
          end

          local section = selection.section.name
          local action, message, choices

          if selection.item and selection.item.first == fn.line(".") then -- Discard File
            if section == "untracked" then
              message = ("Discard %q?"):format(selection.item.name)
              action = function()
                a.util.scheduler()

                local bufnr = fn.bufexists(selection.item.name)
                if bufnr and bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
                  api.nvim_buf_delete(bufnr, { force = true })
                end

                fn.delete(selection.item.escaped_path)
              end
            elseif section == "unstaged" then
              if selection.item.mode:match("^[UA][UA]") then
                choices = { "&ours", "&theirs", "&conflict", "&abort" }
                action = function()
                  local choice = input.get_choice(
                    "Discard conflict by taking...",
                    { values = choices, default = #choices }
                  )

                  if choice == "o" then
                    git.cli.checkout.ours.files(selection.item.absolute_path).call_sync()
                    git.status.stage { selection.item.name }
                  elseif choice == "t" then
                    git.cli.checkout.theirs.files(selection.item.absolute_path).call_sync()
                    git.status.stage { selection.item.name }
                  elseif choice == "c" then
                    git.cli.checkout.merge.files(selection.item.absolute_path).call_sync()
                    git.status.stage { selection.item.name }
                  end
                end
              else
                message = ("Discard %q?"):format(selection.item.name)
                action = function()
                  if selection.item.mode == "A" then
                    git.index.reset { selection.item.escaped_path }

                    a.util.scheduler()

                    local bufnr = fn.bufexists(selection.item.name)
                    if bufnr and bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
                      api.nvim_buf_delete(bufnr, { force = true })
                    end

                    fn.delete(selection.item.escaped_path)
                  else
                    git.index.checkout { selection.item.name }
                  end
                end
              end
            elseif section == "staged" then
              message = ("Discard %q?"):format(selection.item.name)
              action = function()
                if selection.item.mode == "N" then
                  git.index.reset { selection.item.escaped_path }

                  a.util.scheduler()

                  local bufnr = fn.bufexists(selection.item.name)
                  if bufnr and bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
                    api.nvim_buf_delete(bufnr, { force = true })
                  end

                  fn.delete(selection.item.escaped_path)
                elseif selection.item.mode == "M" then
                  git.index.reset { selection.item.escaped_path }
                  git.index.checkout { selection.item.escaped_path }
                elseif selection.item.mode == "R" then
                  -- https://github.com/magit/magit/blob/28bcd29db547ab73002fb81b05579e4a2e90f048/lisp/magit-apply.el#L675
                  git.index.reset_HEAD(selection.item.name, selection.item.original_name)
                  git.index.checkout { selection.item.original_name }
                elseif selection.item.mode == "D" then
                  git.index.reset_HEAD(selection.item.escaped_path)
                  git.index.checkout { selection.item.escaped_path }
                else
                  error(
                    ("Unhandled file mode %q for %q"):format(selection.item.mode, selection.item.escaped_path)
                  )
                end
              end
            elseif section == "stashes" then
              message = ("Discard %q?"):format(selection.item.name)
              action = function()
                git.stash.drop(selection.item.name:match("(stash@{%d+})"))
              end
            end
          elseif selection.item then -- Discard Hunk
            if selection.item.mode == "UU" then
              -- TODO: https://github.com/emacs-mirror/emacs/blob/master/lisp/vc/smerge-mode.el
              notification.warn("Resolve conflicts in file before discarding hunks.")
              return
            end

            local hunk =
              self.buffer.ui:item_hunks(selection.item, selection.first_line, selection.last_line, false)[1]

            local patch = git.index.generate_patch(selection.item, hunk, hunk.from, hunk.to, true)

            if section == "untracked" then
              message = "Discard hunk?"
              action = function()
                local hunks =
                  self.buffer.ui:item_hunks(selection.item, selection.first_line, selection.last_line, false)

                local patch =
                  git.index.generate_patch(selection.item, hunks[1], hunks[1].from, hunks[1].to, true)

                git.index.apply(patch, { reverse = true })
                git.index.apply(patch, { reverse = true })
              end
            elseif section == "unstaged" then
              message = "Discard hunk?"
              action = function()
                git.index.apply(patch, { reverse = true })
              end
            elseif section == "staged" then
              message = "Discard hunk?"
              action = function()
                git.index.apply(patch, { index = true, reverse = true })
              end
            end
          else -- Discard Section
            if section == "untracked" then
              message = ("Discard %s files?"):format(#selection.section.items)
              action = function()
                a.util.scheduler()

                for _, file in ipairs(selection.section.items) do
                  local bufnr = fn.bufexists(file.name)
                  if bufnr and bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
                    api.nvim_buf_delete(bufnr, { force = true })
                  end

                  fn.delete(file.escaped_path)
                end
              end
            elseif section == "unstaged" then
              local conflict = false
              for _, item in ipairs(selection.section.items) do
                if item.mode == "UU" then
                  conflict = true
                  break
                end
              end

              if conflict then
                -- TODO: https://github.com/magit/magit/blob/28bcd29db547ab73002fb81b05579e4a2e90f048/lisp/magit-apply.el#L626
                notification.warn("Resolve conflicts before discarding section.")
                return
              else
                message = ("Discard %s files?"):format(#selection.section.items)
                action = function()
                  git.index.checkout_unstaged()
                end
              end
            elseif section == "staged" then
              message = ("Discard %s files?"):format(#selection.section.items)
              action = function()
                local new_files = {}
                local staged_files_modified = {}
                local staged_files_renamed = {}
                local staged_files_deleted = {}

                for _, item in ipairs(selection.section.items) do
                  if item.mode == "N" or item.mode == "A" then
                    table.insert(new_files, item.escaped_path)
                  elseif item.mode == "M" then
                    table.insert(staged_files_modified, item.escaped_path)
                  elseif item.mode == "R" then
                    table.insert(staged_files_renamed, item)
                  elseif item.mode == "D" then
                    table.insert(staged_files_deleted, item.escaped_path)
                  else
                    error(("Unknown file mode %q for %q"):format(item.mode, item.escaped_path))
                  end
                end

                if #new_files > 0 then
                  -- ensure the file is deleted
                  git.index.reset(new_files)

                  a.util.scheduler()

                  for _, file in ipairs(new_files) do
                    local bufnr = fn.bufexists(file.name)
                    if bufnr and bufnr > 0 and api.nvim_buf_is_valid(bufnr) then
                      api.nvim_buf_delete(bufnr, { force = true })
                    end

                    fn.delete(file.escaped_path)
                  end
                end

                if #staged_files_modified > 0 then
                  git.index.reset(staged_files_modified)
                  git.index.checkout(staged_files_modified)
                end

                if #staged_files_renamed > 0 then
                  for _, item in ipairs(staged_files_renamed) do
                    git.index.reset_HEAD(item.name, item.original_name)
                    git.index.checkout { item.original_name }
                    fn.delete(item.escaped_path)
                  end
                end

                if #staged_files_deleted > 0 then
                  git.index.reset_HEAD(unpack(staged_files_deleted))
                  git.index.checkout(staged_files_deleted)
                end
              end
            elseif section == "stashes" then
              message = ("Discard %s stashes?"):format(#selection.section.items)
              action = function()
                for _, stash in ipairs(selection.section.items) do
                  git.stash.drop(stash.name:match("(stash@{%d+})"))
                end
              end
            end
          end

          if action and (choices or input.get_permission(message)) then
            action()
            self:refresh()
          end
        end),
        [mappings["GoToNextHunkHeader"]] = function()
          local c = self.buffer.ui:get_component_under_cursor(function(c)
            return c.options.tag == "Diff" or c.options.tag == "Hunk" or c.options.tag == "File"
          end)
          local section = self.buffer.ui:get_current_section()

          if c and section then
            local _, section_last = section:row_range_abs()
            local next_location

            if c.options.tag == "Diff" then
              next_location = fn.line(".") + 1
            elseif c.options.tag == "File" then
              vim.cmd("normal! zo")
              next_location = fn.line(".") + 1
            elseif c.options.tag == "Hunk" then
              local _, last = c:row_range_abs()
              next_location = last + 1
            end

            if next_location < section_last then
              self.buffer:move_cursor(next_location)
            end

            vim.cmd("normal! zt")
          end
        end,
        [mappings["GoToPreviousHunkHeader"]] = function()
          local function previous_hunk_header(self, line)
            local c = self.buffer.ui:get_component_on_line(line, function(c)
              return c.options.tag == "Diff" or c.options.tag == "Hunk" or c.options.tag == "File"
            end)

            if c then
              local first, _ = c:row_range_abs()
              if fn.line(".") == first then
                first = previous_hunk_header(self, line - 1)
              end

              return first
            end
          end

          local previous_header = previous_hunk_header(self, fn.line("."))
          if previous_header then
            self.buffer:move_cursor(previous_header)
            vim.cmd("normal! zt")
          end
        end,
        [mappings["InitRepo"]] = function()
          git.init.init_repo()
        end,
        [mappings["Stage"]] = a.void(function()
          local stagable = self.buffer.ui:get_hunk_or_filename_under_cursor()
          local section = self.buffer.ui:get_current_section()

          if stagable and section then
            if section.options.section == "staged" then
              return
            end

            if stagable.hunk then
              local item = self.buffer.ui:get_item_under_cursor()
              local patch =
                git.index.generate_patch(item, stagable.hunk, stagable.hunk.from, stagable.hunk.to)

              git.index.apply(patch, { cached = true })
              self:refresh()
            elseif stagable.filename then
              if section.options.section == "unstaged" then
                git.status.stage { stagable.filename }
                self:refresh()
              elseif section.options.section == "untracked" then
                git.index.add { stagable.filename }
                self:refresh()
              end
            end
          elseif section then
            if section.options.section == "untracked" then
              git.status.stage_untracked()
              self:refresh()
            elseif section.options.section == "unstaged" then
              git.status.stage_modified()
              self:refresh()
            end
          end
        end),
        [mappings["StageAll"]] = a.void(function()
          git.status.stage_all()
          self:refresh()
        end),
        [mappings["StageUnstaged"]] = a.void(function()
          git.status.stage_modified()
          self:refresh()
        end),
        [mappings["Unstage"]] = a.void(function()
          local unstagable = self.buffer.ui:get_hunk_or_filename_under_cursor()

          local section = self.buffer.ui:get_current_section()
          if section and section.options.section ~= "staged" then
            return
          end

          if unstagable then
            if unstagable.hunk then
              local item = self.buffer.ui:get_item_under_cursor()
              local patch = git.index.generate_patch(
                item,
                unstagable.hunk,
                unstagable.hunk.from,
                unstagable.hunk.to,
                true
              )

              git.index.apply(patch, { cached = true, reverse = true })
              self:refresh()
            elseif unstagable.filename then
              git.status.unstage { unstagable.filename }
              self:refresh()
            end
          elseif section then
            git.status.unstage_all()
            self:refresh()
          end
        end),
        [mappings["UnstageStaged"]] = a.void(function()
          git.status.unstage_all()
          self:refresh()
        end),
        [mappings["GoToFile"]] = function()
          local item = self.buffer.ui:get_item_under_cursor()

          -- Goto FILE
          if item and item.absolute_path then
            local cursor
            -- If the cursor is located within a hunk, we need to turn that back into a line number in the file.
            if rawget(item, "diff") then
              local line = self.buffer:cursor_line()

              for _, hunk in ipairs(item.diff.hunks) do
                if line >= hunk.first and line <= hunk.last then
                  local offset = line - hunk.first
                  local row = hunk.disk_from + offset - 1

                  for i = 1, offset do
                    -- If the line is a deletion, we need to adjust the row
                    if string.sub(hunk.lines[i], 1, 1) == "-" then
                      row = row - 1
                    end
                  end

                  cursor = { row, 0 }
                  break
                end
              end
            end

            self:close()

            vim.schedule(function()
              vim.cmd("edit! " .. fn.fnameescape(item.absolute_path))

              if cursor then
                api.nvim_win_set_cursor(0, cursor)
              end
            end)

            return
          end

          -- Goto COMMIT
          local ref = self.buffer.ui:get_yankable_under_cursor()
          if ref then
            require("neogit.buffers.commit_view").new(ref):open()
          end
        end,
        [mappings["TabOpen"]] = function()
          local item = self.buffer.ui:get_item_under_cursor()

          if item and item.escaped_path then
            local cursor
            -- If the cursor is located within a hunk, we need to turn that back into a line number in the file.
            if rawget(item, "diff") then
              local line = self.buffer:cursor_line()

              for _, hunk in ipairs(item.diff.hunks) do
                if line >= hunk.first and line <= hunk.last then
                  local offset = line - hunk.first
                  local row = hunk.disk_from + offset - 1

                  for i = 1, offset do
                    -- If the line is a deletion, we need to adjust the row
                    if string.sub(hunk.lines[i], 1, 1) == "-" then
                      row = row - 1
                    end
                  end

                  cursor = { row, 0 }
                  break
                end
              end
            end

            vim.cmd.tabedit(item.escaped_path)
            if cursor then
              api.nvim_win_set_cursor(0, cursor)
            end
          end
        end,
        [mappings["SplitOpen"]] = function()
          local item = self.buffer.ui:get_item_under_cursor()

          if item and item.escaped_path then
            local cursor
            -- If the cursor is located within a hunk, we need to turn that back into a line number in the file.
            if rawget(item, "diff") then
              local line = self.buffer:cursor_line()

              for _, hunk in ipairs(item.diff.hunks) do
                if line >= hunk.first and line <= hunk.last then
                  local offset = line - hunk.first
                  local row = hunk.disk_from + offset - 1

                  for i = 1, offset do
                    -- If the line is a deletion, we need to adjust the row
                    if string.sub(hunk.lines[i], 1, 1) == "-" then
                      row = row - 1
                    end
                  end

                  cursor = { row, 0 }
                  break
                end
              end
            end

            vim.cmd.split(item.escaped_path)
            if cursor then
              api.nvim_win_set_cursor(0, cursor)
            end
          end
        end,
        [mappings["VSplitOpen"]] = function()
          local item = self.buffer.ui:get_item_under_cursor()

          if item and item.escaped_path then
            local cursor
            -- If the cursor is located within a hunk, we need to turn that back into a line number in the file.
            if rawget(item, "diff") then
              local line = self.buffer:cursor_line()

              for _, hunk in ipairs(item.diff.hunks) do
                if line >= hunk.first and line <= hunk.last then
                  local offset = line - hunk.first
                  local row = hunk.disk_from + offset - 1

                  for i = 1, offset do
                    -- If the line is a deletion, we need to adjust the row
                    if string.sub(hunk.lines[i], 1, 1) == "-" then
                      row = row - 1
                    end
                  end

                  cursor = { row, 0 }
                  break
                end
              end
            end

            vim.cmd.vsplit(item.escaped_path)
            if cursor then
              api.nvim_win_set_cursor(0, cursor)
            end
          end
        end,
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("BisectPopup")] = popups.open("bisect", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("CherryPickPopup")] = popups.open("cherry_pick", function(p)
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("CommitPopup")] = popups.open("commit", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
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
          p { commits = { self.buffer.ui:get_commit_under_cursor() } }
        end),
        [popups.mapping_for("ResetPopup")] = popups.open("reset", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("TagPopup")] = popups.open("tag", function(p)
          p { commit = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("StashPopup")] = popups.open("stash", function(p)
          local stash = self.buffer.ui:get_yankable_under_cursor()
          p { name = stash and stash:match("^stash@{%d+}") }
        end),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          local section = self.buffer.ui:get_selection().sections[1]
          local item = self.buffer.ui:get_yankable_under_cursor()
          p {
            section = { name = section },
            item = { name = item },
          }
        end),
        [popups.mapping_for("IgnorePopup")] = popups.open("ignore", function(p)
          local path = self.buffer.ui:get_hunk_or_filename_under_cursor()
          p {
            paths = { path and path.escaped_path },
            git_root = git.repo.git_root,
          }
        end),
        [popups.mapping_for("HelpPopup")] = popups.open("help", function(p)
          -- Since any other popup can be launched from help, build an ENV for any of them.
          local path = self.buffer.ui:get_hunk_or_filename_under_cursor()
          local section = self.buffer.ui:get_selection().sections[1]
          local item = self.buffer.ui:get_yankable_under_cursor()
          local stash = self.buffer.ui:get_yankable_under_cursor()
          local commit = self.buffer.ui:get_commit_under_cursor()
          local commits = { commit }

          p {
            branch = { commits = commits },
            cherry_pick = { commits = commits },
            commit = { commit = commit },
            merge = { commit = commit },
            push = { commit = commit },
            rebase = { commit = commit },
            revert = { commits = commits },
            bisect = { commits = commits },
            reset = { commit = commit },
            tag = { commit = commit },
            stash = { name = stash and stash:match("^stash@{%d+}") },
            diff = {
              section = { name = section },
              item = { name = item },
            },
            ignore = {
              paths = { path and path.escaped_path },
              git_root = git.repo.git_root,
            },
            remote = {},
            fetch = {},
            pull = {},
            log = {},
            worktree = {},
          }
        end),
        [popups.mapping_for("RemotePopup")] = popups.open("remote"),
        [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        [popups.mapping_for("LogPopup")] = popups.open("log"),
        [popups.mapping_for("WorktreePopup")] = popups.open("worktree"),
      },
    },
    initialize = function()
      vim.cmd.lcd(cwd)
      self:dispatch_refresh(nil, "initialize")

      self.prev_autochdir = vim.o.autochdir
      vim.o.autochdir = false
    end,
    render = function()
      if self.state.initialized then
        return ui.Status(self.state, self.config)
      else
        return {}
      end
    end,
    ---@param buffer Buffer
    ---@param _win any
    after = function(buffer, _win)
      if config.values.filewatcher.enabled then
        logger.debug("[STATUS] Starting file watcher")
        self.watcher = Watcher.new(self, self.root):start()
      end

      buffer:move_cursor(buffer.ui:first_section().first)
    end,
  }
end

function M:close()
  if self.buffer then
    logger.debug("[STATUS] Closing Buffer")
    self.buffer:close()
    self.buffer = nil
  end

  if self.watcher then
    logger.debug("[STATUS] Stopping Watcher")
    self.watcher:stop()
  end

  if self.prev_autochdir then
    vim.o.autochdir = self.prev_autochdir
  end

  M.unregister()
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
  logger.debug("[STATUS] Beginning refresh from " .. (reason or "unknown"))
  -- if self.frozen then
  --   return
  -- end

  local permit = self:_get_refresh_lock(reason)

  git.repo:refresh {
    source = "status",
    partial = partial,
    callback = function()
      logger.debug("[STATUS][Refresh Callback] Running")
      if not self.buffer then
        logger.debug("[STATUS][Refresh Callback] Buffer no longer exists - bail")
        return
      end

      local cursor, view
      if self.buffer:is_focused() then
        cursor = self.buffer.ui:get_cursor_location()
        view = self.buffer:save_view()
      end

      logger.debug("[STATUS][Refresh Callback] Rendering UI")
      self.buffer.ui:render(unpack(ui.Status(self.state, self.config)))

      if cursor and view then
        self.buffer:restore_view(view, self.buffer.ui:resolve_cursor_location(cursor))
      end

      api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed", modeline = false })

      permit:forget()
      logger.info("[STATUS] Refresh lock is now free")
    end,
  }
end

M.dispatch_refresh = util.debounce_trailing(
  100,
  a.void(function(self, partial, reason)
    if self:_is_refresh_locked() then
      logger.debug("[STATUS] Refresh lock is active. Skipping refresh from " .. (reason or "unknown"))
    else
      logger.debug("[STATUS] Dispatching Refresh")
      self:refresh(partial, reason)
    end
  end)
)

function M:reset()
  logger.debug("[STATUS] Resetting repo and refreshing")
  git.repo:reset()
  self:refresh(nil, "reset")
end

function M:dispatch_reset()
  a.run(function()
    self:reset()
  end)
end

function M:_is_refresh_locked()
  return self.refresh_lock.permits == 0
end

function M:_get_refresh_lock(reason)
  local permit = self.refresh_lock:acquire()
  logger.debug(("[STATUS]: Acquired refresh lock:"):format(reason or "unknown"))

  vim.defer_fn(function()
    if self:_is_refresh_locked() then
      permit:forget()
      logger.debug(("[STATUS]: Refresh lock for %s expired after 10 seconds"):format(reason or "unknown"))
    end
  end, 10000)

  return permit
end

return M
