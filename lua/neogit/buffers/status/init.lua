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
    M.instance:close()
  end
  M.instance = self

  if self.is_open then
    return
  end
  self.is_open = true

  kind = kind or config.values.kind
  local mappings = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitStatus",
    filetype = "NeogitStatus",
    context_highlight = true,
    kind = kind,
    disable_line_numbers = config.values.disable_line_numbers,
    autocmds = {
      ["BufUnload"] = function()
        watcher.instance:stop()
        self.is_open = false
        vim.o.autochdir = self.prev_autochdir
      end,
    },
    mappings = {
      v = {
        [mappings["Discard"]] = a.void(function()
          -- TODO: Discard Stash?
          -- TODO: Discard Section?
          local discardable = self.buffer.ui:get_hunks_and_filenames_in_selection()

          local total_files = #discardable.files.staged
            + #discardable.files.unstaged
            + #discardable.files.untracked

          local total_hunks = #discardable.hunks.staged
            + #discardable.hunks.unstaged
            + #discardable.hunks.untracked

          if total_files > 0 then
            if input.get_permission(("Discard %s files?"):format(total_files)) then
              if #discardable.files.staged > 0 then
                local new_files = {}
                local modified_files = {}

                for _, file in ipairs(discardable.files.staged) do
                  if file.mode == "A" then
                    table.insert(new_files, file.escaped_path)
                  else
                    table.insert(modified_files, file.escaped_path)
                  end
                end

                if #modified_files > 0 then
                  git.index.reset(modified_files)
                  git.index.checkout(modified_files)
                end

                if #new_files > 0 then
                  git.index.reset(new_files)

                  a.util.scheduler()

                  for _, file in ipairs(new_files) do
                    local bufnr = fn.bufexists(file.name)
                    if bufnr and bufnr > 0 then
                      api.nvim_buf_delete(bufnr, { force = true })
                    end

                    fn.delete(file.escaped_path)
                  end
                end
              end

              if #discardable.files.unstaged > 0 then
                git.index.checkout(util.map(discardable.files.unstaged, function(f)
                  return f.escaped_path
                end))
              end

              if #discardable.files.untracked > 0 then
                a.util.scheduler()

                for _, file in ipairs(discardable.files.untracked) do
                  local bufnr = fn.bufexists(file.name)
                  if bufnr and bufnr > 0 then
                    api.nvim_buf_delete(bufnr, { force = true })
                  end

                  fn.delete(file.escaped_path)
                end
              end
            end
          end

          if total_hunks > 0 then
            if input.get_permission(("Discard %s hunks?"):format(total_hunks)) then
              if #discardable.files.staged > 0 then
                local new_files = {}
                local modified_files = {}

                for _, file in ipairs(discardable.files.staged) do
                  if file.mode == "A" then
                    table.insert(new_files, file.escaped_path)
                  else
                    table.insert(modified_files, file.escaped_path)
                  end
                end

                if #modified_files > 0 then
                  git.index.reset(modified_files)
                  git.index.checkout(modified_files)
                end

                if #new_files > 0 then
                  git.index.reset(new_files)

                  a.util.scheduler()

                  for _, file in ipairs(new_files) do
                    local bufnr = fn.bufexists(file.name)
                    if bufnr and bufnr > 0 then
                      api.nvim_buf_delete(bufnr, { force = true })
                    end

                    fn.delete(file.escaped_path)
                  end
                end
              end

              if #discardable.files.unstaged > 0 then
                git.index.checkout(util.map(discardable.files.unstaged, function(f)
                  return f.escaped_path
                end))
              end

              if #discardable.files.untracked > 0 then
                a.util.scheduler()

                for _, file in ipairs(discardable.files.untracked) do
                  local bufnr = fn.bufexists(file.name)
                  if bufnr and bufnr > 0 then
                    api.nvim_buf_delete(bufnr, { force = true })
                  end

                  fn.delete(file.escaped_path)
                end
              end
            end
          end

          -- if discardable then
          --   local section = self.buffer.ui:get_current_section()
          --   local item = self.buffer.ui:get_item_under_cursor()
          --
          --   if not section or not item then
          --     return
          --   end
          --
          --   if discardable.hunk then
          --     local hunk = discardable.hunk
          --     local patch = git.index.generate_patch(item, hunk, hunk.from, hunk.to, true)
          --
          --     if input.get_permission("Discard hunk?") then
          --       if section.options.section == "staged" then
          --         git.index.apply(patch, { index = true, reverse = true })
          --       else
          --         git.index.apply(patch, { reverse = true })
          --       end
          --     end

          self:refresh()
        end),
        [mappings["Stage"]] = a.void(function()
          local stagable = self.buffer.ui:get_hunk_or_filename_under_cursor()
          local section = self.buffer.ui:get_current_section()

          local cursor = self.buffer:cursor_line()
          if stagable and section then
            if section.options.section == "staged" then
              return
            end

            if stagable.hunk then
              local item = self.buffer.ui:get_item_under_cursor()
              local patch =
                git.index.generate_patch(item, stagable.hunk, stagable.hunk.from, stagable.hunk.to)

              git.index.apply(patch, { cached = true })
              cursor = stagable.hunk.first
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

          if cursor then
            self.buffer:move_cursor(cursor)
          end

          self:refresh()
        end),
        [mappings["Unstage"]] = a.void(function()
          local unstagable = self.buffer.ui:get_hunk_or_filename_under_cursor()

          local section = self.buffer.ui:get_current_section()
          if section and section.options.section ~= "staged" then
            return
          end

          -- TODO: Cursor Placement
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
        [popups.mapping_for("BranchPopup")] = popups.open("branch", function(p)
          p { commits = self.buffer.ui:get_commit_under_cursor() }
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
          -- TODO: Verify
          local stash = self.buffer.ui:get_yankable_under_cursor()
          p { name = stash and stash:match("^stash@{%d+}") }
        end),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          -- TODO: Verify
          local section = self.buffer.ui:get_current_section().options.section
          local item = self.buffer.ui:get_yankable_under_cursor()
          p { section = { name = section }, item = { name = item } }
        end),
        [popups.mapping_for("IgnorePopup")] = popups.open("ignore", function(p)
          -- TODO use current absolute paths in selection
          p { paths = {}, git_root = git.repo.git_root }
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
        [mappings["Close"]] = function()
          self:close()
        end,
        [mappings["RefreshBuffer"]] = a.void(function()
          self:refresh()
        end),
        [mappings["Depth1"]] = function()
          -- TODO: Need to work with stashes/recent
          local section = self.buffer.ui:get_current_section()
          if section then
            local start, _ = section:row_range_abs()
            self.buffer:move_cursor(start)
            section:close_all_folds(self.buffer.ui)

            self.buffer.ui:update()
          end
        end,
        [mappings["Depth2"]] = function()
          -- TODO: Need to work with stashes/recent
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
          -- TODO: Need to work with stashes/recent, but same as depth2
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
          -- TODO: Need to work with stashes/recent, but same as depth2
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
          end
        end),
        [mappings["GoToNextHunkHeader"]] = function()
          -- TODO: Doesn't go across file boundaries
          local c = self.buffer.ui:get_component_under_cursor(function(c)
            return c.options.tag == "Diff" or c.options.tag == "Hunk"
          end)

          if c then
            if c.options.tag == "Diff" then
              self.buffer:move_cursor(fn.line(".") + 1)
            else
              local _, last = c:row_range_abs()
              if last == fn.line("$") then
                self.buffer:move_cursor(last)
              else
                self.buffer:move_cursor(last + 1)
              end
            end
            vim.cmd("normal! zt")
          end
        end,
        [mappings["GoToPreviousHunkHeader"]] = function()
          -- TODO: Doesn't go across file boundaries
          local function previous_hunk_header(self, line)
            local c = self.buffer.ui:get_component_on_line(line, function(c)
              return c.options.tag == "Diff" or c.options.tag == "Hunk"
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
            api.nvim_win_set_cursor(0, { previous_header, 0 })
            vim.cmd("normal! zt")
          end
        end,
        [mappings["InitRepo"]] = function()
          git.init.init_repo()
        end,
        [mappings["Stage"]] = a.void(function()
          -- TODO: Cursor Placement
          local stagable = self.buffer.ui:get_hunk_or_filename_under_cursor()
          local section = self.buffer.ui:get_current_section()

          local cursor = self.buffer:cursor_line()
          if stagable and section then
            if section.options.section == "staged" then
              return
            end

            if stagable.hunk then
              local item = self.buffer.ui:get_item_under_cursor()
              local patch =
                git.index.generate_patch(item, stagable.hunk, stagable.hunk.from, stagable.hunk.to)

              git.index.apply(patch, { cached = true })
              cursor = stagable.hunk.first
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

          if cursor then
            self.buffer:move_cursor(cursor)
          end

          self:refresh()
        end),
        [mappings["StageAll"]] = a.void(function()
          -- TODO: Cursor Placement
          git.status.stage_all()
          self:refresh()
        end),
        [mappings["StageUnstaged"]] = a.void(function()
          -- TODO: Cursor Placement
          git.status.stage_modified()
          self:refresh()
        end),
        [mappings["Unstage"]] = a.void(function()
          local unstagable = self.buffer.ui:get_hunk_or_filename_under_cursor()

          local section = self.buffer.ui:get_current_section()
          if section and section.options.section ~= "staged" then
            return
          end

          -- TODO: Cursor Placement
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
          -- TODO: Cursor Placement
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
          p { section = { name = section }, item = { name = item } }
        end),
        [popups.mapping_for("IgnorePopup")] = popups.open("ignore", function(p)
          -- TODO use current absolute paths in selection
          p { paths = {}, git_root = git.repo.git_root }
        end),
        [popups.mapping_for("RemotePopup")] = popups.open("remote"),
        [popups.mapping_for("FetchPopup")] = popups.open("fetch"),
        [popups.mapping_for("PullPopup")] = popups.open("pull"),
        [popups.mapping_for("HelpPopup")] = popups.open("help"),
        [popups.mapping_for("LogPopup")] = popups.open("log"),
        [popups.mapping_for("WorktreePopup")] = popups.open("worktree"),
      },
    },
    initialize = function()
      self.prev_autochdir = vim.o.autochdir
      vim.o.autochdir = false
    end,
    render = function()
      -- TODO: Figure out a way to remove the very last empty line from the last visible section.
      --       it's created by the newline spacer between sections.
      return ui.Status(self.state, self.config)
    end,
    after = function()
      vim.cmd([[setlocal nowrap]])

      if config.values.filewatcher.enabled then
        watcher.new(git.repo:git_path():absolute()):start()
      end
    end,
  }
end

function M:close()
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
    self.buffer:focus()
  end
end

-- TODO: Allow passing some kind of cursor identifier into this, which can be injected into the renderer to
-- find the location of a new named element to set the cursor to upon update.
--
-- For example, when staging all items in untracked section via `s`, cursor should be updated to go to header of
-- staged section
--
function M:refresh(partial, reason)
  -- if self.frozen then
  --   return
  -- end

  local permit = self:_get_refresh_lock(reason)

  git.repo:refresh {
    source = "status",
    partial = partial,
    callback = function()
      if not self.buffer then
        return
      end

      -- TODO: move cursor restoration logic here?

      self.buffer.ui:render(unpack(ui.Status(git.repo, self.config)))

      api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed", modeline = false })

      permit:forget()
      logger.info("[STATUS BUFFER]: Refresh lock is now free")
    end,
  }
end

function M:dispatch_refresh(partial, reason)
  a.run(function()
    if self:_is_refresh_locked() then
      logger.debug("[STATUS] Refresh lock is active. Skipping refresh from " .. reason)
    else
      self:refresh(partial, reason)
    end
  end)
end

function M:reset()
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
  logger.debug(("[STATUS BUFFER]: Acquired refresh lock:"):format(reason or "unknown"))

  vim.defer_fn(function()
    if self:_is_refresh_locked() then
      permit:forget()
      logger.debug(
        ("[STATUS BUFFER]: Refresh lock for %s expired after 10 seconds"):format(reason or "unknown")
      )
    end
  end, 10000)

  return permit
end

return M
