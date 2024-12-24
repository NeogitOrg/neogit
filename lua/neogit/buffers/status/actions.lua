-- NOTE: `v_` prefix stands for visual mode actions, `n_` for normal mode.
--
local a = require("plenary.async")
local git = require("neogit.lib.git")
local popups = require("neogit.popups")
local logger = require("neogit.logger")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")
local config = require("neogit.config")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local fn = vim.fn
local api = vim.api

local function cleanup_dir(dir)
  if vim.in_fast_event() then
    a.util.scheduler()
  end

  for name, type in vim.fs.dir(dir, { depth = math.huge }) do
    if type == "file" then
      local bufnr = fn.bufnr(name)
      if bufnr > 0 then
        api.nvim_buf_delete(bufnr, { force = false })
      end
    end
  end

  fn.delete(dir, "rf")
end

local function cleanup_items(...)
  if vim.in_fast_event() then
    a.util.scheduler()
  end

  for _, item in ipairs { ... } do
    local bufnr = fn.bufnr(item.name)
    if bufnr > 0 then
      api.nvim_buf_delete(bufnr, { force = false })
    end

    fn.delete(fn.fnameescape(item.name))
  end
end

---@param self StatusBuffer
---@param item StatusItem
---@return table|nil
local function translate_cursor_location(self, item)
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

        return { row, 0 }
      end
    end
  end
end

local function open(type, path, cursor)
  local command = ("silent! %s %s | %s | redraw! | norm! zz"):format(
    type,
    fn.fnameescape(path),
    cursor and cursor[1] or "1"
  )

  logger.debug("[Status - Open] '" .. command .. "'")

  vim.cmd(command)
end

local M = {}

---@param self StatusBuffer
M.v_discard = function(self)
  return a.void(function()
    local selection = self.buffer.ui:get_selection()

    local discard_message = "Discard selection?"
    local hunk_count = 0
    local file_count = 0

    local patches = {}
    local invalidated_diffs = {}
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
            logger.debug(("Discarding %d hunks from %q"):format(#hunks, item.name))

            hunk_count = hunk_count + #hunks
            if hunk_count > 1 then
              discard_message = ("Discard %s hunks?"):format(hunk_count)
            end

            for _, hunk in ipairs(hunks) do
              table.insert(invalidated_diffs, "*:" .. item.name)
              table.insert(patches, function()
                local patch =
                  git.index.generate_patch(hunk, { from = hunk.from, to = hunk.to, reverse = true })

                logger.debug(("Discarding Patch: %s"):format(patch))

                git.index.apply(patch, {
                  index = section.name == "staged",
                  reverse = true,
                })
              end)
            end
          else
            discard_message = ("Discard %s files?"):format(file_count)
            logger.debug(("Discarding in section %s %s"):format(section.name, item.name))
            table.insert(invalidated_diffs, "*:" .. item.name)

            if section.name == "untracked" then
              table.insert(untracked_files, item)
            elseif section.name == "unstaged" then
              if item.mode == "A" then
                table.insert(new_files, item)
              else
                table.insert(unstaged_files, item)
              end
            elseif section.name == "staged" then
              if item.mode == "N" then
                table.insert(new_files, item)
              else
                table.insert(staged_files_modified, item)
              end
            end
          end
        end
      elseif section.name == "stashes" then
        discard_message = ("Discard %s stashes?"):format(#selection.items)

        for _, stash in ipairs(selection.items) do
          table.insert(stashes, stash.name:match("(stash@{%d+})"))
        end

        table.sort(stashes)
        stashes = util.reverse(stashes)
      end
    end

    if input.get_permission(discard_message) then
      if #patches > 0 then
        for _, patch in ipairs(patches) do
          patch()
        end
      end

      if #untracked_files > 0 then
        cleanup_items(unpack(untracked_files))
      end

      if #unstaged_files > 0 then
        git.index.checkout(util.map(unstaged_files, function(item)
          return item.escaped_path
        end))
      end

      if #new_files > 0 then
        git.index.reset(util.map(unstaged_files, function(item)
          return item.escaped_path
        end))
        cleanup_items(unpack(new_files))
      end

      if #staged_files_modified > 0 then
        local paths = git.index.reset(util.map(staged_files_modified, function(item)
          return item.escaped_path
        end))
        git.index.reset(paths)
        git.index.checkout(paths)
      end

      -- TODO: Investigate why, when dropping multiple stashes, the UI doesn't get updated at the end
      if #stashes > 0 then
        for _, stash in ipairs(stashes) do
          git.stash.drop(stash)
        end
      end

      self:dispatch_refresh({ update_diff = invalidated_diffs }, "v_discard")
    end
  end)
end

---@param self StatusBuffer
M.v_stage = function(self)
  return a.void(function()
    local selection = self.buffer.ui:get_selection()

    local untracked_files = {}
    local unstaged_files = {}
    local patches = {}
    local invalidated_diffs = {}

    for _, section in ipairs(selection.sections) do
      if section.name == "unstaged" or section.name == "untracked" then
        for _, item in ipairs(section.items) do
          if item.mode == "UU" then
            notification.info("Conflicts must be resolved before staging lines")
            return
          end

          local hunks = self.buffer.ui:item_hunks(item, selection.first_line, selection.last_line, true)
          table.insert(invalidated_diffs, "*:" .. item.name)

          if #hunks > 0 then
            for _, hunk in ipairs(hunks) do
              table.insert(patches, git.index.generate_patch(hunk.hunk, { from = hunk.from, to = hunk.to }))
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
      self:dispatch_refresh({ update_diffs = invalidated_diffs }, "n_stage")
    end
  end)
end

---@param self StatusBuffer
M.v_unstage = function(self)
  return a.void(function()
    local selection = self.buffer.ui:get_selection()

    local files = {}
    local patches = {}
    local invalidated_diffs = {}

    for _, section in ipairs(selection.sections) do
      if section.name == "staged" then
        for _, item in ipairs(section.items) do
          local hunks = self.buffer.ui:item_hunks(item, selection.first_line, selection.last_line, true)
          table.insert(invalidated_diffs, "*:" .. item.name)

          if #hunks > 0 then
            for _, hunk in ipairs(hunks) do
              table.insert(
                patches,
                git.index.generate_patch(hunk, { from = hunk.from, to = hunk.to, reverse = true })
              )
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
      self:dispatch_refresh({ update_diffs = invalidated_diffs }, "v_unstage")
    end
  end)
end

---@param self StatusBuffer
M.v_branch_popup = function(self)
  return popups.open("branch", function(p)
    p { commits = self.buffer.ui:get_commits_in_selection() }
  end)
end

---@param self StatusBuffer
M.v_cherry_pick_popup = function(self)
  return popups.open("cherry_pick", function(p)
    p { commits = self.buffer.ui:get_commits_in_selection() }
  end)
end

---@param self StatusBuffer
M.v_commit_popup = function(self)
  return popups.open("commit", function(p)
    local commits = self.buffer.ui:get_commits_in_selection()
    if #commits == 1 then
      p { commit = commits[1] }
    end
  end)
end

---@param self StatusBuffer
M.v_merge_popup = function(self)
  return popups.open("merge", function(p)
    local commits = self.buffer.ui:get_commits_in_selection()
    if #commits == 1 then
      p { commit = commits[1] }
    end
  end)
end

---@param self StatusBuffer
M.v_push_popup = function(self)
  return popups.open("push", function(p)
    local commits = self.buffer.ui:get_commits_in_selection()
    if #commits == 1 then
      p { commit = commits[1] }
    end
  end)
end

---@param self StatusBuffer
M.v_rebase_popup = function(self)
  return popups.open("rebase", function(p)
    local commits = self.buffer.ui:get_commits_in_selection()
    if #commits == 1 then
      p { commit = commits[1] }
    end
  end)
end

---@param self StatusBuffer
M.v_revert_popup = function(self)
  return popups.open("revert", function(p)
    p { commits = self.buffer.ui:get_commits_in_selection() }
  end)
end

---@param self StatusBuffer
M.v_reset_popup = function(self)
  return popups.open("reset", function(p)
    local commits = self.buffer.ui:get_commits_in_selection()
    if #commits == 1 then
      p { commit = commits[1] }
    end
  end)
end

---@param self StatusBuffer
M.v_tag_popup = function(self)
  return popups.open("tag", function(p)
    local commits = self.buffer.ui:get_commits_in_selection()
    if #commits == 1 then
      p { commit = commits[1] }
    end
  end)
end

---@param self StatusBuffer
M.v_stash_popup = function(self)
  return popups.open("stash", function(p)
    local stash = self.buffer.ui:get_yankable_under_cursor()
    p { name = stash and stash:match("^stash@{%d+}") }
  end)
end

---@param self StatusBuffer
M.v_diff_popup = function(self)
  return popups.open("diff", function(p)
    local section = self.buffer.ui:get_selection().section
    local item = self.buffer.ui:get_yankable_under_cursor()
    p { section = { name = section and section.name }, item = { name = item } }
  end)
end

---@param self StatusBuffer
M.v_ignore_popup = function(self)
  return popups.open("ignore", function(p)
    p { paths = self.buffer.ui:get_filepaths_in_selection(), worktree_root = git.repo.worktree_root }
  end)
end

---@param self StatusBuffer
M.v_bisect_popup = function(self)
  return popups.open("bisect", function(p)
    p { commits = self.buffer.ui:get_commits_in_selection() }
  end)
end

---@param _self StatusBuffer
M.v_remote_popup = function(_self)
  return popups.open("remote")
end

---@param _self StatusBuffer
M.v_fetch_popup = function(_self)
  return popups.open("fetch")
end

---@param _self StatusBuffer
M.v_pull_popup = function(_self)
  return popups.open("pull")
end

---@param _self StatusBuffer
M.v_help_popup = function(_self)
  return popups.open("help")
end

---@param _self StatusBuffer
M.v_log_popup = function(_self)
  return popups.open("log")
end

---@param _self StatusBuffer
M.v_worktree_popup = function(_self)
  return popups.open("worktree")
end

---@param self StatusBuffer
M.n_down = function(self)
  return function()
    if vim.v.count > 0 then
      vim.cmd("norm! " .. vim.v.count .. "j")
    else
      vim.cmd("norm! j")
    end

    if self.buffer:get_current_line()[1] == "" then
      vim.cmd("norm! j")
    end
  end
end

---@param self StatusBuffer
M.n_up = function(self)
  return function()
    if vim.v.count > 0 then
      vim.cmd("norm! " .. vim.v.count .. "k")
    else
      vim.cmd("norm! k")
    end

    if self.buffer:get_current_line()[1] == "" then
      vim.cmd("norm! k")
    end
  end
end

---@param self StatusBuffer
M.n_toggle = function(self)
  return function()
    local fold = self.buffer.ui:get_fold_under_cursor()
    if fold then
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
  end
end

---@param self StatusBuffer
M.n_close = function(self)
  return require("neogit.lib.ui.helpers").close_topmost(self)
end

---@param self StatusBuffer
M.n_open_or_scroll_down = function(self)
  return function()
    local commit = self.buffer.ui:get_commit_under_cursor()
    if commit then
      require("neogit.buffers.commit_view").open_or_scroll_down(commit)
    end
  end
end

---@param self StatusBuffer
M.n_open_or_scroll_up = function(self)
  return function()
    local commit = self.buffer.ui:get_commit_under_cursor()
    if commit then
      require("neogit.buffers.commit_view").open_or_scroll_up(commit)
    end
  end
end

---@param self StatusBuffer
M.n_refresh_buffer = function(self)
  return a.void(function()
    self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_refresh_buffer")
  end)
end

---@param self StatusBuffer
M.n_depth1 = function(self)
  return function()
    local section = self.buffer.ui:get_current_section()
    if section then
      local start, last = section:row_range_abs()
      if self.buffer:cursor_line() < start or self.buffer:cursor_line() >= last then
        return
      end

      self.buffer:move_cursor(start)
      section:close_all_folds(self.buffer.ui)

      self.buffer.ui:update()
    end
  end
end

---@param self StatusBuffer
M.n_depth2 = function(self)
  return function()
    local section = self.buffer.ui:get_current_section()
    local row = self.buffer.ui:get_component_under_cursor()

    if section then
      local start, last = section:row_range_abs()
      if self.buffer:cursor_line() < start or self.buffer:cursor_line() >= last then
        return
      end

      self.buffer:move_cursor(start)

      section:close_all_folds(self.buffer.ui)
      section:open_all_folds(self.buffer.ui, 1)

      self.buffer.ui:update()

      if row then
        local start, _ = row:row_range_abs()
        self.buffer:move_cursor(start)
      end
    end
  end
end

---@param self StatusBuffer
M.n_depth3 = function(self)
  return function()
    local section = self.buffer.ui:get_current_section()
    local context = self.buffer.ui:get_cursor_context()

    if section then
      local start, last = section:row_range_abs()
      if self.buffer:cursor_line() < start or self.buffer:cursor_line() >= last then
        return
      end

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
  end
end

---@param self StatusBuffer
M.n_depth4 = function(self)
  return function()
    local section = self.buffer.ui:get_current_section()
    local context = self.buffer.ui:get_cursor_context()

    if section then
      local start, last = section:row_range_abs()
      if self.buffer:cursor_line() < start or self.buffer:cursor_line() >= last then
        return
      end

      self.buffer:move_cursor(start)
      section:close_all_folds(self.buffer.ui)
      section:open_all_folds(self.buffer.ui, 3)

      self.buffer.ui:update()

      if context then
        local start, _ = context:row_range_abs()
        self.buffer:move_cursor(start)
      end
    end
  end
end

---@param _self StatusBuffer
M.n_command_history = function(_self)
  return a.void(function()
    require("neogit.buffers.git_command_history"):new():show()
  end)
end

---@param _self StatusBuffer
M.n_show_refs = function(_self)
  return a.void(function()
    require("neogit.buffers.refs_view").new(git.refs.list_parsed(), git.repo.worktree_root):open()
  end)
end

---@param self StatusBuffer
M.n_yank_selected = function(self)
  return function()
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
  end
end

---@param self StatusBuffer
M.n_discard = function(self)
  return a.void(function()
    git.index.update()

    local selection = self.buffer.ui:get_selection()
    if not selection.section then
      return
    end

    local section = selection.section.name
    local action, message, choices
    local refresh = {}

    if selection.item and selection.item.first == fn.line(".") then -- Discard File
      if section == "untracked" then
        local mode = git.config.get("status.showUntrackedFiles"):read()

        refresh = { update_diffs = { "untracked:" .. selection.item.name } }
        if mode == "all" then
          message = ("Discard %q?"):format(selection.item.name)
          action = function()
            cleanup_items(selection.item)
          end
        else
          message = ("Recursively discard %q?"):format(selection.item.name)
          action = function()
            cleanup_dir(selection.item.name)
          end
        end
      elseif section == "unstaged" then
        if selection.item.mode:match("^[UAD][UAD]") then
          choices = { "&ours", "&theirs", "&conflict", "&abort" }
          action = function()
            local choice =
              input.get_choice("Discard conflict by taking...", { values = choices, default = #choices })

            if choice == "o" then
              git.cli.checkout.ours.files(selection.item.absolute_path).call { await = true }
              git.status.stage { selection.item.name }
            elseif choice == "t" then
              git.cli.checkout.theirs.files(selection.item.absolute_path).call { await = true }
              git.status.stage { selection.item.name }
            elseif choice == "c" then
              git.cli.checkout.merge.files(selection.item.absolute_path).call { await = true }
              git.status.stage { selection.item.name }
            end
          end
          refresh = { update_diffs = { "unstaged:" .. selection.item.name } }
        else
          message = ("Discard %q?"):format(selection.item.name)
          action = function()
            if selection.item.mode == "A" then
              git.index.reset { selection.item.escaped_path }
              cleanup_items(selection.item)
            else
              git.index.checkout { selection.item.name }
            end
          end
        end
        refresh = { update_diffs = { "unstaged:" .. selection.item.name } }
      elseif section == "staged" then
        if selection.item.mode:match("^[UAD][UAD]") then
          choices = { "&ours", "&theirs", "&conflict", "&abort" }
          action = function()
            local choice =
              input.get_choice("Discard conflict by taking...", { values = choices, default = #choices })

            if choice == "o" then
              git.cli.checkout.ours.files(selection.item.absolute_path).call { await = true }
              git.status.stage { selection.item.name }
            elseif choice == "t" then
              git.cli.checkout.theirs.files(selection.item.absolute_path).call { await = true }
              git.status.stage { selection.item.name }
            elseif choice == "c" then
              git.cli.checkout.merge.files(selection.item.absolute_path).call { await = true }
              git.status.stage { selection.item.name }
            end
          end
          refresh = { update_diffs = { "unstaged:" .. selection.item.name } }
        else
          message = ("Discard %q?"):format(selection.item.name)
          action = function()
            if selection.item.mode == "N" then
              git.index.reset { selection.item.escaped_path }
              cleanup_items(selection.item)
            elseif selection.item.mode == "M" then
              git.index.reset { selection.item.escaped_path }
              git.index.checkout { selection.item.escaped_path }
            elseif selection.item.mode == "R" then
              git.index.reset_HEAD(selection.item.name, selection.item.original_name)
              git.index.checkout { selection.item.original_name }
              cleanup_items(selection.item)
            elseif selection.item.mode == "D" then
              git.index.reset_HEAD(selection.item.escaped_path)
              git.index.checkout { selection.item.escaped_path }
            else
              error(
                ("Unhandled file mode %q for %q"):format(selection.item.mode, selection.item.escaped_path)
              )
            end
          end
          refresh = { update_diffs = { "staged:" .. selection.item.name } }
        end
      elseif section == "stashes" then
        message = ("Discard %q?"):format(selection.item.name)
        action = function()
          git.stash.drop(selection.item.name:match("(stash@{%d+})"))
        end
        refresh = {}
      end
    elseif selection.item then -- Discard Hunk
      if selection.item.mode == "UU" then
        notification.warn("Resolve conflicts in file before discarding hunks.")
        return
      end

      local hunk =
        self.buffer.ui:item_hunks(selection.item, selection.first_line, selection.last_line, false)[1]

      local patch = git.index.generate_patch(hunk, { reverse = true })

      if section == "untracked" then
        message = "Discard hunk?"
        action = function()
          git.index.apply(patch, { reverse = true })
        end
        refresh = { update_diffs = { "untracked:" .. selection.item.name } }
      elseif section == "unstaged" then
        message = "Discard hunk?"
        action = function()
          git.index.apply(patch, { reverse = true })
        end
        refresh = { update_diffs = { "unstaged:" .. selection.item.name } }
      elseif section == "staged" then
        message = "Discard hunk?"
        action = function()
          git.index.apply(patch, { index = true, reverse = true })
        end
        refresh = { update_diffs = { "staged:" .. selection.item.name } }
      end
    else -- Discard Section
      if section == "untracked" then
        message = ("Discard %s files?"):format(#selection.section.items)
        action = function()
          cleanup_items(unpack(selection.section.items))
        end
        refresh = { update_diffs = { "untracked:*" } }
      elseif section == "unstaged" then
        local conflict = false
        for _, item in ipairs(selection.section.items) do
          if item.mode == "UU" then
            conflict = true
            break
          end
        end

        if conflict then
          -- TODO: https://github.com/magit/magit/blob/28bcd29db547ab73002fb81b05579e4a2e90f048/lisp/magit-apply.el#L515
          notification.warn("Resolve conflicts before discarding section.")
          return
        else
          message = ("Discard %s files?"):format(#selection.section.items)
          action = function()
            git.index.checkout_unstaged()
          end
          refresh = { update_diffs = { "unstaged:*" } }
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
            cleanup_items(unpack(new_files))
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
        refresh = { update_diffs = { "staged:*" } }
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
      self:dispatch_refresh(refresh, "n_discard")
    end
  end)
end

---@param self StatusBuffer
M.n_go_to_next_hunk_header = function(self)
  return function()
    local c = self.buffer.ui:get_component_under_cursor(function(c)
      return c.options.tag == "Diff" or c.options.tag == "Hunk" or c.options.tag == "Item"
    end)
    local section = self.buffer.ui:get_current_section()

    if c and section then
      local _, section_last = section:row_range_abs()
      local next_location

      if c.options.tag == "Diff" then
        next_location = fn.line(".") + 1
      elseif c.options.tag == "Item" then
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
  end
end

---@param self StatusBuffer
M.n_go_to_previous_hunk_header = function(self)
  return function()
    local function previous_hunk_header(self, line)
      local c = self.buffer.ui:get_component_on_line(line, function(c)
        return c.options.tag == "Diff" or c.options.tag == "Hunk" or c.options.tag == "Item"
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
  end
end

---@param _self StatusBuffer
M.n_init_repo = function(_self)
  return function()
    git.init.init_repo()
  end
end

---@param self StatusBuffer
M.n_rename = function(self)
  return a.void(function()
    local selection = self.buffer.ui:get_selection()
    local paths = git.files.all_tree()

    if
      selection.item
      and selection.item.escaped_path
      and git.files.is_tracked(selection.item.escaped_path)
    then
      paths = util.deduplicate(util.merge({ selection.item.escaped_path }, paths))
    end

    local selected = FuzzyFinderBuffer.new(paths):open_async { prompt_prefix = "Rename file" }
    if (selected or "") == "" then
      return
    end

    local destination = input.get_user_input("Move to", { completion = "dir", prepend = selected })
    if (destination or "") == "" then
      return
    end

    assert(destination, "must have a destination")
    local success = git.files.move(selected, destination)

    if not success then
      notification.warn("Renaming failed")
    end

    self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_rename")
  end)
end

---@param self StatusBuffer
M.n_untrack = function(self)
  return a.void(function()
    local selection = self.buffer.ui:get_selection()
    local paths = git.files.all_tree()

    if
      selection.item
      and selection.item.escaped_path
      and git.files.is_tracked(selection.item.escaped_path)
    then
      paths = util.deduplicate(util.merge({ selection.item.escaped_path }, paths))
    end

    local selected = FuzzyFinderBuffer.new(paths)
      :open_async { prompt_prefix = "Untrack file(s)", allow_multi = true }
    if selected and #selected > 0 and git.files.untrack(selected) then
      local message
      if #selected > 1 then
        message = ("%s files untracked"):format(#selected)
      else
        message = ("%q untracked"):format(selected[1])
      end

      notification.info(message)
      self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_untrack")
    end
  end)
end

---@param self StatusBuffer
M.v_untrack = function(self)
  return a.void(function()
    local selection = self.buffer.ui:get_selection()
    local selected_paths = util.filter_map(selection.items or {}, function(item)
      if git.files.is_tracked(item.escaped_path) then
        return item.escaped_path
      end
    end)

    local paths = util.deduplicate(util.merge(selected_paths, git.files.all_tree()))
    local selected = FuzzyFinderBuffer.new(paths)
      :open_async { prompt_prefix = "Untrack file(s)", allow_multi = true }
    if selected and #selected > 0 and git.files.untrack(selected) then
      local message
      if #selected > 1 then
        message = ("Untracked %s files"):format(#selected)
      else
        message = ("%q untracked"):format(selected[1])
      end

      notification.info(message)
      self:dispatch_refresh({ update_diffs = { "*:*" } }, "v_untrack")
    end
  end)
end

---@param self StatusBuffer
M.n_stage = function(self)
  return a.void(function()
    local stagable = self.buffer.ui:get_hunk_or_filename_under_cursor()
    local section = self.buffer.ui:get_current_section()
    local selection = self.buffer.ui:get_selection()

    if stagable and section then
      if section.options.section == "staged" then
        return
      end

      if selection.item and selection.item.mode == "UU" then
        if config.check_integration("diffview") then
          require("neogit.integrations.diffview").open("conflict", selection.item.name, {
            on_close = {
              handle = self.buffer.handle,
              fn = function()
                if not git.merge.is_conflicted(selection.item.name) then
                  git.status.stage { selection.item.name }
                  self:dispatch_refresh({ update_diffs = { "*:" .. selection.item.name } }, "n_stage")

                  if not git.merge.any_conflicted() then
                    popups.open("merge")()
                  end
                end
              end,
            },
          })
        else
          notification.info("Conflicts must be resolved before staging")
          return
        end
      elseif stagable.hunk then
        local item = self.buffer.ui:get_item_under_cursor()
        assert(item, "Item cannot be nil")

        local patch = git.index.generate_patch(stagable.hunk)
        git.index.apply(patch, { cached = true })
        self:dispatch_refresh({ update_diffs = { "*:" .. item.escaped_path } }, "n_stage")
      elseif stagable.filename then
        if section.options.section == "unstaged" then
          git.status.stage { stagable.filename }
          self:dispatch_refresh({ update_diffs = { "*:" .. stagable.filename } }, "n_stage")
        elseif section.options.section == "untracked" then
          git.index.add { stagable.filename }
          self:dispatch_refresh({ update_diffs = { "*:" .. stagable.filename } }, "n_stage")
        end
      end
    elseif section then
      if section.options.section == "untracked" then
        git.status.stage_untracked()
        self:dispatch_refresh({ update_diffs = { "untracked:*" } }, "n_stage")
      elseif section.options.section == "unstaged" then
        if git.status.any_unmerged() then
          if config.check_integration("diffview") then
            require("neogit.integrations.diffview").open("conflict", nil, {
              on_close = {
                handle = self.buffer.handle,
                fn = function()
                  if not git.merge.any_conflicted() then
                    git.status.stage_modified()
                    self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_stage")
                    popups.open("merge")()
                  end
                end,
              },
            })
          else
            notification.info("Conflicts must be resolved before staging")
            return
          end
        else
          git.status.stage_modified()
          self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_stage")
        end
      end
    end
  end)
end

---@param self StatusBuffer
M.n_stage_all = function(self)
  return a.void(function()
    git.status.stage_all()
    self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_stage_all")
  end)
end

---@param self StatusBuffer
M.n_stage_unstaged = function(self)
  return a.void(function()
    git.status.stage_modified()
    self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_stage_unstaged")
  end)
end

---@param self StatusBuffer
M.n_unstage = function(self)
  return a.void(function()
    local unstagable = self.buffer.ui:get_hunk_or_filename_under_cursor()

    local section = self.buffer.ui:get_current_section()
    if section and section.options.section ~= "staged" then
      return
    end

    if unstagable then
      if unstagable.hunk then
        local item = self.buffer.ui:get_item_under_cursor()
        assert(item, "Item cannot be nil")
        local patch = git.index.generate_patch(
          unstagable.hunk,
          { from = unstagable.hunk.from, to = unstagable.hunk.to, reverse = true }
        )

        git.index.apply(patch, { cached = true, reverse = true })
        self:dispatch_refresh({ update_diffs = { "*:" .. item.escaped_path } }, "n_unstage")
      elseif unstagable.filename then
        git.status.unstage { unstagable.filename }
        self:dispatch_refresh({ update_diffs = { "*:" .. unstagable.filename } }, "n_unstage")
      end
    elseif section then
      git.status.unstage_all()
      self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_unstage")
    end
  end)
end

---@param self StatusBuffer
M.n_unstage_staged = function(self)
  return a.void(function()
    git.status.unstage_all()
    self:dispatch_refresh({ update_diffs = { "*:*" } }, "n_unstage_all")
  end)
end

---@param self StatusBuffer
M.n_goto_file = function(self)
  return function()
    local item = self.buffer.ui:get_item_under_cursor()

    -- Goto FILE
    if item and item.absolute_path then
      local cursor = translate_cursor_location(self, item)
      self:close()
      vim.schedule_wrap(open)("edit", item.absolute_path, cursor)
      return
    end

    -- Goto COMMIT
    local ref = self.buffer.ui:get_yankable_under_cursor()
    if ref then
      require("neogit.buffers.commit_view").new(ref):open()
    end
  end
end

---@param self StatusBuffer
M.n_tab_open = function(self)
  return function()
    local item = self.buffer.ui:get_item_under_cursor()

    if item and item.absolute_path then
      open("tabedit", item.absolute_path, translate_cursor_location(self, item))
    end
  end
end

---@param self StatusBuffer
M.n_split_open = function(self)
  return function()
    local item = self.buffer.ui:get_item_under_cursor()

    if item and item.absolute_path then
      open("split", item.absolute_path, translate_cursor_location(self, item))
    end
  end
end

---@param self StatusBuffer
M.n_vertical_split_open = function(self)
  return function()
    local item = self.buffer.ui:get_item_under_cursor()

    if item and item.absolute_path then
      open("vsplit", item.absolute_path, translate_cursor_location(self, item))
    end
  end
end

---@param self StatusBuffer
M.n_branch_popup = function(self)
  return popups.open("branch", function(p)
    p { commits = { self.buffer.ui:get_commit_under_cursor() } }
  end)
end

---@param self StatusBuffer
M.n_bisect_popup = function(self)
  return popups.open("bisect", function(p)
    p { commits = { self.buffer.ui:get_commit_under_cursor() } }
  end)
end

---@param self StatusBuffer
M.n_cherry_pick_popup = function(self)
  return popups.open("cherry_pick", function(p)
    p { commits = { self.buffer.ui:get_commit_under_cursor() } }
  end)
end

---@param self StatusBuffer
M.n_commit_popup = function(self)
  return popups.open("commit", function(p)
    p { commit = self.buffer.ui:get_commit_under_cursor() }
  end)
end

---@param self StatusBuffer
M.n_merge_popup = function(self)
  return popups.open("merge", function(p)
    p { commit = self.buffer.ui:get_commit_under_cursor() }
  end)
end

---@param self StatusBuffer
M.n_push_popup = function(self)
  return popups.open("push", function(p)
    p { commit = self.buffer.ui:get_commit_under_cursor() }
  end)
end

---@param self StatusBuffer
M.n_rebase_popup = function(self)
  return popups.open("rebase", function(p)
    p { commit = self.buffer.ui:get_commit_under_cursor() }
  end)
end

---@param self StatusBuffer
M.n_revert_popup = function(self)
  return popups.open("revert", function(p)
    p { commits = { self.buffer.ui:get_commit_under_cursor() } }
  end)
end

---@param self StatusBuffer
M.n_reset_popup = function(self)
  return popups.open("reset", function(p)
    p { commit = self.buffer.ui:get_commit_under_cursor() }
  end)
end

---@param self StatusBuffer
M.n_tag_popup = function(self)
  return popups.open("tag", function(p)
    p { commit = self.buffer.ui:get_commit_under_cursor() }
  end)
end

---@param self StatusBuffer
M.n_stash_popup = function(self)
  return popups.open("stash", function(p)
    local stash = self.buffer.ui:get_yankable_under_cursor()
    p { name = stash and stash:match("^stash@{%d+}") }
  end)
end

---@param self StatusBuffer
M.n_diff_popup = function(self)
  return popups.open("diff", function(p)
    local section = self.buffer.ui:get_selection().section
    local item = self.buffer.ui:get_yankable_under_cursor()
    p {
      section = { name = section and section.name },
      item = { name = item },
    }
  end)
end

---@param self StatusBuffer
M.n_ignore_popup = function(self)
  return popups.open("ignore", function(p)
    local path = self.buffer.ui:get_hunk_or_filename_under_cursor()
    p {
      paths = { path and path.escaped_path },
      worktree_root = git.repo.worktree_root,
    }
  end)
end

---@param self StatusBuffer
M.n_help_popup = function(self)
  return popups.open("help", function(p)
    -- Since any other popup can be launched from help, build an ENV for any of them.
    local path = self.buffer.ui:get_hunk_or_filename_under_cursor()
    local section = self.buffer.ui:get_selection().section
    local section_name
    if section then
      section_name = section.name
    end

    local item = self.buffer.ui:get_yankable_under_cursor()
    local stash = self.buffer.ui:get_yankable_under_cursor()
    local commit = self.buffer.ui:get_commit_under_cursor()
    local commits = { commit }

    -- TODO: Pass selection here so we can stage/unstage etc stuff
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
        section = { name = section_name },
        item = { name = item },
      },
      ignore = {
        paths = { path and path.escaped_path },
        worktree_root = git.repo.worktree_root,
      },
      remote = {},
      fetch = {},
      pull = {},
      log = {},
      worktree = {},
    }
  end)
end

---@param _self StatusBuffer
M.n_remote_popup = function(_self)
  return popups.open("remote")
end

---@param _self StatusBuffer
M.n_fetch_popup = function(_self)
  return popups.open("fetch")
end

---@param _self StatusBuffer
M.n_pull_popup = function(_self)
  return popups.open("pull")
end

---@param _self StatusBuffer
M.n_log_popup = function(_self)
  return popups.open("log")
end

---@param _self StatusBuffer
M.n_worktree_popup = function(_self)
  return popups.open("worktree")
end

---@param _self StatusBuffer
M.n_open_tree = function(_self)
  return a.void(function()
    local template = "https://${host}/${owner}/${repository}/tree/${branch_name}"

    local upstream = git.branch.upstream_remote()
    if not upstream then
      return
    end

    local url = git.remote.get_url(upstream)[1]
    local format_values = git.remote.parse(url)
    format_values["branch_name"] = git.branch.current()

    vim.ui.open(util.format(template, format_values))
  end)
end

---@param self StatusBuffer|nil
M.n_command = function(self)
  local process = require("neogit.process")
  local runner = require("neogit.runner")

  return a.void(function()
    local cmd =
      input.get_user_input(("Run command in %s"):format(git.repo.worktree_root), { prepend = "git " })
    if not cmd then
      return
    end

    local cmd = vim.split(cmd, " ")
    table.insert(cmd, 2, "--no-pager")
    table.insert(cmd, 3, "--no-optional-locks")

    local proc = process.new {
      cmd = cmd,
      cwd = git.repo.worktree_root,
      env = {},
      on_error = function()
        return false
      end,
      git_hook = true,
      suppress_console = false,
      user_command = true,
    }

    proc:show_console()

    runner.call(proc, {
      pty = true,
      callback = function()
        if self then
          self:dispatch_refresh()
        end
      end,
    })
  end)
end

---@param self StatusBuffer
M.n_next_section = function(self)
  return function()
    local section = self.buffer.ui:get_current_section()
    if section then
      local position = section.position.row_end + 2
      self.buffer:move_cursor(position)
    else
      self.buffer:move_cursor(self.buffer.ui:first_section().first + 1)
    end
  end
end

---@param self StatusBuffer
M.n_prev_section = function(self)
  return function()
    local section = self.buffer.ui:get_current_section()
    if section then
      local prev_section = self.buffer.ui:get_current_section(section.position.row_start - 1)
      if prev_section then
        self.buffer:move_cursor(prev_section.position.row_start + 1)
        return
      end
    end

    self.buffer:win_exec("norm! gg")
  end
end

return M
