local config = require("neogit.config")
local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.status.ui")
local popups = require("neogit.popups")
local git = require("neogit.lib.git")
local watcher = require("neogit.watcher")
local a = require("plenary.async")

local api = vim.api

---@class StatusBuffer
---@field is_open boolean whether the buffer is currently visible
---@field buffer Buffer instance
---@field state NeogitRepo
---@field config NeogitConfig
local M = {}
M.__index = M

---@param state NeogitRepo
---@param config NeogitConfig
---@return StatusBuffer
function M.new(state, config)
  local instance = {
    is_open = false,
    state = state,
    config = config,
    buffer = nil,
  }

  setmetatable(instance, M)

  return instance
end

function M:close()
  self.is_open = false
  self.buffer:close()
  self.buffer = nil
end

function M:refresh()
  git.repo:refresh {
    source = "status",
    callback = function()
      self.buffer.ui:render(unpack(ui.Status(git.repo, self.config)))
    end,
  }
  -- diff with current UI
  -- only update deltas
end

-- TODO
-- Save/restore cursor location
-- Redrawing w/ lock, that doesn't discard opened/closed diffs, keeps cursor location
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
--
-- Mappings:
--  Ensure it will work when passing multiple mappings to the same function
--
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
    name = "NeogitStatusNew",
    filetype = "NeogitStatusNew",
    context_highlight = true,
    kind = kind,
    disable_line_numbers = config.values.disable_line_numbers,
    autocmds = {
      ["BufUnload"] = function()
        M.watcher:stop()
        M.instance.is_open = false
      end,
    },
    mappings = {
      v = {},
      n = {
        [mappings["Close"]] = function()
          self:close()
        end,
        [mappings["CommandHistory"]] = function()
          require("neogit.buffers.git_command_history"):new():show()
        end,
        [mappings["Console"]] = function()
          require("neogit.process").show_console()
        end,
        [mappings["Depth1"]] = function()
          -- TODO
        end,
        [mappings["Depth2"]] = function()
          -- TODO
        end,
        [mappings["Depth3"]] = function()
          -- TODO
        end,
        [mappings["Depth4"]] = function()
          -- TODO
        end,
        [mappings["Discard"]] = function()
          -- TODO
        end,
        [mappings["GoToFile"]] = function()
          local item = self.buffer.ui:get_item_under_cursor()

          if item and item.absolute_path then
            local cursor
            if rawget(item, "diff") then
              -- If the cursor is located within a hunk, we need to turn that back into
              -- a line number in the file.
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

            -- Copied from original - not sure what it's for, entirely
            if not vim.o.hidden and vim.bo.buftype == "" and not vim.bo.readonly and vim.fn.bufname() ~= "" then
              vim.cmd("update")
            end

            vim.cmd.edit(vim.fn.fnameescape(vim.fn.fnamemodify(item.absolute_path, ":~:.")))
            if cursor then
              vim.api.nvim_win_set_cursor(0, cursor)
            end

            return
          end

          local ref = self.buffer.ui:get_yankable_under_cursor()
          if ref then
            require("neogit.buffers.commit_view").new(ref):open()
          end
        end,
        [mappings["GoToNextHunkHeader"]] = function()
          -- TODO: Doesn't go across file boundaries
          local c = self.buffer.ui:get_component_under_cursor(function(c)
            return c.options.tag == "Diff" or c.options.tag == "Hunk"
          end)

          if c then
            if c.options.tag == "Diff" then
              self.buffer:move_cursor(vim.fn.line(".") + 1)
            else
              local _, last = c:row_range_abs()
              if last == vim.fn.line("$") then
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
              if vim.fn.line(".") == first then
                first = previous_hunk_header(self, line - 1)
              end

              return first
            end
          end

          local previous_header = previous_hunk_header(self, vim.fn.line("."))
          if previous_header then
            api.nvim_win_set_cursor(0, { previous_header, 0 })
            vim.cmd("normal! zt")
          end
        end,
        [mappings["InitRepo"]] = function()
          git.init.init_repo()
        end,
        [mappings["RefreshBuffer"]] = function()
          -- TODO
        end,
        [mappings["ShowRefs"]] = function()
          require("neogit.buffers.refs_view").new(git.refs.list_parsed()):open()
        end,
        [mappings["SplitOpen"]] = function()
          -- TODO
        end,
        [mappings["Stage"]] = a.void(function()
          local stagable = self.buffer.ui:get_hunk_or_filename_under_cursor()

          if stagable then
            if stagable.hunk then
              local item = self.buffer.ui:get_item_under_cursor()
              local patch =
                git.index.generate_patch(item, stagable.hunk, stagable.hunk.from, stagable.hunk.to)

              git.index.apply(patch, { cached = true })
            elseif stagable.filename then
              local section = self.buffer.ui:get_current_section()

              if section == "unstaged" then
                git.status.stage { stagable.filename }
              elseif section == "untracked" then
                git.index.add { stagable.filename }
              end
            end

            self:refresh()
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
        [mappings["TabOpen"]] = function()
          -- TODO
        end,
        [mappings["Unstage"]] = a.void(function()
          local stagable = self.buffer.ui:get_hunk_or_filename_under_cursor()

          if stagable then
            if stagable.hunk then
              local item = self.buffer.ui:get_item_under_cursor()
              local patch =
                git.index.generate_patch(item, stagable.hunk, stagable.hunk.from, stagable.hunk.to, true)

              git.index.apply(patch, { cached = true, reverse = true })
            elseif stagable.filename then
              local section = self.buffer.ui:get_current_section()

              if section == "staged" then
                git.status.unstage { stagable.filename }
              end
            end

            self:refresh()
          end
        end),
        [mappings["UnstageStaged"]] = a.void(function()
          git.status.unstage_all()
          self:refresh()
        end),
        [mappings["VSplitOpen"]] = function()
          -- TODO
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
          -- TODO: Pass in stash name if its under the cursor
          p { name = self.buffer.ui:get_commit_under_cursor() }
        end),
        [popups.mapping_for("DiffPopup")] = popups.open("diff", function(p)
          -- TODO use current section/item
          p { section = {}, item = {} }
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
      return ui.Status(self.state, self.config)
    end,
    after = function()
      vim.cmd([[setlocal nowrap]])
      M.watcher = watcher.new(git.repo:git_path():absolute())
    end,
  }
end

return M
