-- TODO
-- on-close hook to teardown stuff
--
-- Actions:
-- Staging / Unstaging / Discarding
--
-- Contexts:
-- - Normal
--  - Section
--  - File
--  - Hunk
-- - Visual
--  - Files in selection
--  - Hunks in selection
--  - Lines in selection

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
local watcher = require("neogit.watcher")
local a = require("plenary.async")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")

local logger = require("neogit.logger") -- TODO: Add logging
local notification = require("neogit.lib.notification") -- TODO

local api = vim.api
local fn = vim.fn

---@class Semaphore
---@field permits number
---@field acquire function

---@class StatusBuffer
---@field is_open boolean whether the buffer is currently visible
---@field buffer Buffer instance
---@field state NeogitRepo
---@field config NeogitConfig
---@field frozen boolean
---@field refresh_lock Semaphore
local M = {}
M.__index = M

---@param state NeogitRepo
---@param config NeogitConfig
---@return StatusBuffer
function M.new(state, config)
  local instance = {
    is_open = false,
    -- frozen = false,
    state = state,
    config = config,
    buffer = nil,
    watcher = nil,
    refresh_lock = a.control.Semaphore.new(1),
  }

  setmetatable(instance, M)

  return instance
end

function M:open(kind)
  if M.instance and M.instance.is_open then
    logger.debug("[STATUS] An Instance is already open - closing it")
    M.instance:close()
  end
  M.instance = self

  if self.is_open then
    logger.debug("[STATUS] This Instance is already open - bailing")
    return
  end
  self.is_open = true

  kind = kind or config.values.kind
  logger.debug("[STATUS] Opening kind: " .. kind)

  local mappings = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitStatus",
    filetype = "NeogitStatus",
    context_highlight = true,
    kind = kind,
    disable_line_numbers = config.values.disable_line_numbers,
    autocmds = {
      ["BufUnload"] = function()
        logger.debug("[STATUS] Running BufUnload autocmd")
        watcher.instance:stop()
        self.is_open = false
        vim.o.autochdir = self.prev_autochdir
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
          local staged_files_new = {}
          local staged_files_modified = {}

          for _, section in ipairs(selection.sections) do
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
                  table.insert(unstaged_files, item.escaped_path)
                elseif section.name == "staged" then
                  if item.mode == "N" then
                    table.insert(staged_files_new, item.escaped_path)
                  else
                    table.insert(staged_files_modified, item.escaped_path)
                  end
                end
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
                if bufnr and bufnr > 0 then
                  api.nvim_buf_delete(bufnr, { force = true })
                end

                fn.delete(file.escaped_path)
              end
            end

            if #unstaged_files > 0 then
              git.index.checkout(unstaged_files)
            end

            if #staged_files_new > 0 then
              git.index.reset(staged_files_new)

              a.util.scheduler()

              for _, file in ipairs(staged_files_new) do
                local bufnr = fn.bufexists(file.name)
                if bufnr and bufnr > 0 then
                  api.nvim_buf_delete(bufnr, { force = true })
                end

                fn.delete(file.escaped_path)
              end
            end

            if #staged_files_modified > 0 then
              git.index.reset(staged_files_modified)
              git.index.checkout(staged_files_modified)
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
          local section = self.buffer.ui:get_current_section().options.section
          local item = self.buffer.ui:get_yankable_under_cursor()
          p { section = { name = section }, item = { name = item } }
        end),
        [popups.mapping_for("IgnorePopup")] = popups.open("ignore", function(p)
          p { paths = self.buffer.ui:get_filepaths_in_selection(), git_root = git.repo.git_root }
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
            -- section" from a UX perspective.
            if fold.options.tag == "Section" and self.buffer:get_current_line()[1] == "" then
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
        [mappings["Close"]] = function()
          self:close()
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
        [mappings["CommandHistory"]] = function()
          require("neogit.buffers.git_command_history"):new():show()
        end,
        [mappings["Console"]] = function()
          require("neogit.process").show_console()
        end,
        [mappings["ShowRefs"]] = function()
          require("neogit.buffers.refs_view").new(git.refs.list_parsed()):open()
        end,
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
          -- TODO: Use better selection logic
          -- TODO: Discarding a RENAME should set the filename back to the original
          git.index.update()

          local discardable = self.buffer.ui:get_hunk_or_filename_under_cursor()

          if discardable then
            local section = self.buffer.ui:get_current_section()
            local item = self.buffer.ui:get_item_under_cursor()

            if not section or not item then
              return
            end

            -- TODO: Discard Stash?
            -- TODO: Discard Section?
            if discardable.hunk then
              local hunk = discardable.hunk
              local patch = git.index.generate_patch(item, hunk, hunk.from, hunk.to, true)

              if input.get_permission("Discard hunk?") then
                if section.options.section == "staged" then
                  git.index.apply(patch, { index = true, reverse = true })
                else
                  git.index.apply(patch, { reverse = true })
                end
              end
            elseif discardable.filename then
              if input.get_permission(("Discard %q?"):format(discardable.filename)) then
                if section.options.section == "staged" and item.mode == "M" then -- Modified
                  git.index.reset { discardable.filename }
                  git.index.checkout { discardable.filename }
                elseif section.options.section == "staged" and item.mode == "A" then -- Added
                  git.index.reset { discardable.filename }

                  a.util.scheduler()

                  local bufnr = fn.bufexists(discardable.filename)
                  if bufnr and bufnr > 0 then
                    api.nvim_buf_delete(bufnr, { force = true })
                  end

                  fn.delete(fn.fnameescape(discardable.filename))
                elseif section.options.section == "unstaged" then
                  git.index.checkout { discardable.filename }
                elseif section.options.section == "untracked" then
                  a.util.scheduler()

                  local bufnr = fn.bufexists(discardable.filename)
                  if bufnr and bufnr > 0 then
                    api.nvim_buf_delete(bufnr, { force = true })
                  end

                  fn.delete(fn.fnameescape(discardable.filename))
                end
              end
            end

            self:refresh()
          else
            local section = self.buffer.ui:get_current_section()
            if section then
              if section.options.section == "unstaged" then
                git.index.checkout_unstaged()
              elseif section.options.section == "untracked" then
                P("TODO")
              elseif section.options.section == "staged" then
                P("TODO")
              elseif section.options.section == "stash" then
                P("TODO")
              end

              self:refresh()
            end
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
            elseif stagable.filename then
              if section.options.section == "unstaged" then
                git.status.stage { stagable.filename }
              elseif section.options.section == "untracked" then
                git.index.add { stagable.filename }
              end
            end
          elseif section then
            if section.options.section == "untracked" then
              git.status.stage_untracked()
            elseif section.options.section == "unstaged" then
              git.status.stage_modified()
            end
          end

          self:refresh()
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
            elseif unstagable.filename then
              local section = self.buffer.ui:get_current_section()

              if section and section.options.section == "staged" then
                git.status.unstage { unstagable.filename }
              end
            end

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

            self:close()

            vim.cmd.edit(item.escaped_path)
            if cursor then
              api.nvim_win_set_cursor(0, cursor)
            end

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
          local section = self.buffer.ui:get_current_section().options.section
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
          local section = self.buffer.ui:get_current_section().options.section
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
      logger.debug("[STATUS] Initializing")
      self.prev_autochdir = vim.o.autochdir
      vim.o.autochdir = false
    end,
    render = function()
      return ui.Status(self.state, self.config)
    end,
    after = function()
      vim.cmd([[setlocal nowrap]])

      if config.values.filewatcher.enabled then
        logger.debug("[STATUS] Starting file watcher")
        watcher.new(git.repo:git_path():absolute()):start()
      end
    end,
  }
end

function M:close()
  logger.debug("[STATUS] Closing Buffer")
  if not self.buffer then
    return
  end

  vim.o.autochdir = self.prev_autochdir

  watcher.instance:stop()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
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

      local cursor_line = self.buffer:cursor_line()
      local cursor_goto
      local context = self.buffer.ui:get_cursor_context()
      if context then
        if context.options.tag == "Hunk" then
          if context.index == 1 then
            if #context.parent.children > 1 then
              cursor_line = ({ context:row_range_abs() })[1]
            else
              cursor_line = ({ context:row_range_abs() })[1] - 1
            end
          else
            cursor_line = ({ context.parent.children[context.index - 1]:row_range_abs() })[1]
          end
        elseif context.options.tag == "File" then
          if context.index == 1 then
            if #context.parent.children > 1 then
              -- id is scoped by section. Advance to next file.
              cursor_goto = context.parent.children[2].options.id
            else
              -- Yankable lets us jump from one section to the other. Go to same file in new section.
              cursor_goto = context.options.yankable
            end
          else
            cursor_goto = context.parent.children[context.index - 1].options.id
          end
        else
          -- TODO: profit?
        end
      end

      logger.debug("[STATUS][Refresh Callback] Rendering UI")
      self.buffer.ui:render(unpack(ui.Status(git.repo, self.config)))

      if cursor_goto then
        logger.debug("[STATUS] Cursor goto: " .. cursor_goto)
        local component = self.buffer.ui.node_index:find_by_id(cursor_goto)
        if component then
          cursor_line, _ = component:row_range_abs()
        end
      end

      logger.debug("[STATUS][Refresh Callback] Moving Cursor")
      self.buffer:move_cursor(math.min(fn.line("$"), cursor_line))

      api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed", modeline = false })

      permit:forget()
      logger.info("[STATUS] Refresh lock is now free")
    end,
  }
end

function M:dispatch_refresh(partial, reason)
  a.run(function()
    if self:_is_refresh_locked() then
      logger.debug("[STATUS] Refresh lock is active. Skipping refresh from " .. (reason or "unknown"))
    else
      logger.debug("[STATUS] Dispatching Refresh")
      self:refresh(partial, reason)
    end
  end)
end

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
