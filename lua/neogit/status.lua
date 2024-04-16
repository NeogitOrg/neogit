local Buffer = require("neogit.lib.buffer")
local GitCommandHistory = require("neogit.buffers.git_command_history")
local CommitView = require("neogit.buffers.commit_view")
local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")
local config = require("neogit.config")
local a = require("plenary.async")
local logger = require("neogit.logger")
local Collection = require("neogit.lib.collection")
local F = require("neogit.lib.functional")
local LineBuffer = require("neogit.lib.line_buffer")
local fs = require("neogit.lib.fs")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local watcher = require("neogit.watcher")
local operation = require("neogit.operations")

local api = vim.api
local fn = vim.fn

local M = {}

M.disabled = false

M.prev_autochdir = nil
M.status_buffer = nil
M.commit_view = nil
M.cursor_location = nil

---@class Section
---@field first number
---@field last number
---@field items StatusItem[]
---@field name string
---@field ignore_sign boolean If true will skip drawing the section icons
---@field folded boolean|nil

---@type Section[]
---Sections in order by first lines
M.locations = {}

M.outdated = {}

---@class StatusItem
---@field name string
---@field first number
---@field last number
---@field oid string|nil optional object id
---@field commit CommitLogEntry|nil optional object id
---@field folded boolean|nil
---@field hunks Hunk[]|nil

local head_start = "@"
local add_start = "+"
local del_start = "-"

local function get_section_idx_for_line(linenr)
  for i, l in pairs(M.locations) do
    if l.first <= linenr and linenr <= l.last then
      return i
    end
  end
  return nil
end

local function get_section_item_idx_for_line(linenr)
  local section_idx = get_section_idx_for_line(linenr)
  local section = M.locations[section_idx]

  if section == nil then
    return nil, nil
  end

  for i, item in pairs(section.items) do
    if item.first <= linenr and linenr <= item.last then
      return section_idx, i
    end
  end

  return section_idx, nil
end

---@return Section|nil, StatusItem|nil
local function get_section_item_for_line(linenr)
  local section_idx, item_idx = get_section_item_idx_for_line(linenr)
  local section = M.locations[section_idx]

  if section == nil then
    return nil, nil
  end
  if item_idx == nil then
    return section, nil
  end

  return section, section.items[item_idx]
end

---@return Section|nil, StatusItem|nil
local function get_current_section_item()
  return get_section_item_for_line(vim.fn.line("."))
end

local mode_to_text = {
  M = "Modified",
  N = "New file",
  A = "Added",
  D = "Deleted",
  C = "Copied",
  U = "Updated",
  UU = "Both Modified",
  R = "Renamed",
}

local max_len = #"Modified by us"

local function draw_sign_for_item(item, name)
  if item.folded then
    M.status_buffer:place_sign(item.first, "NeogitClosed:" .. name, "fold_markers")
  else
    M.status_buffer:place_sign(item.first, "NeogitOpen:" .. name, "fold_markers")
  end
end

local function draw_signs()
  if config.values.disable_signs then
    return
  end
  for _, l in ipairs(M.locations) do
    if not l.ignore_sign then
      draw_sign_for_item(l, "section")
      if not l.folded then
        Collection.new(l.items):filter(F.dot("hunks")):each(function(f)
          draw_sign_for_item(f, "item")
          if not f.folded then
            Collection.new(f.hunks):each(function(h)
              draw_sign_for_item(h, "hunk")
            end)
          end
        end)
      end
    end
  end
end

local function format_mode(mode)
  if not mode then
    return ""
  end
  local res = mode_to_text[mode]
  if res then
    return res
  end

  local res = mode_to_text[mode:sub(1, 1)]
  if res then
    return res .. " by us"
  end

  return mode
end

local function draw_buffer()
  M.status_buffer:clear_sign_group("hl")
  M.status_buffer:clear_sign_group("fold_markers")

  local output = LineBuffer.new()
  if not config.values.disable_hint then
    local reversed_status_map = config.get_reversed_status_maps()
    local reversed_popup_map = config.get_reversed_popup_maps()

    local function hint_label(map_name, hint)
      local keys = reversed_status_map[map_name] or reversed_popup_map[map_name]
      if keys and #keys > 0 then
        return string.format("[%s] %s", table.concat(keys, " "), hint)
      else
        return string.format("[<unmapped>] %s", hint)
      end
    end

    local hints = {
      hint_label("Toggle", "toggle diff"),
      hint_label("Stage", "stage"),
      hint_label("Unstage", "unstage"),
      hint_label("Discard", "discard"),
      hint_label("CommitPopup", "commit"),
      hint_label("HelpPopup", "help"),
    }

    output:append("Hint: " .. table.concat(hints, " | "))
    output:append("")
  end

  local new_locations = {}
  local locations_lookup = Collection.new(M.locations):key_by("name")

  output:append(
    string.format(
      "Head:     %s%s %s",
      (git.repo.head.abbrev and git.repo.head.abbrev .. " ") or "",
      git.repo.head.branch,
      git.repo.head.commit_message or "(no commits)"
    )
  )

  table.insert(new_locations, {
    name = "head_branch_header",
    first = #output,
    last = #output,
    items = {},
    ignore_sign = true,
    commit = { oid = git.repo.head.oid },
  })

  if not git.branch.is_detached() then
    if git.repo.upstream.ref then
      output:append(
        string.format(
          "Merge:    %s%s %s",
          (git.repo.upstream.abbrev and git.repo.upstream.abbrev .. " ") or "",
          git.repo.upstream.ref,
          git.repo.upstream.commit_message or "(no commits)"
        )
      )

      table.insert(new_locations, {
        name = "upstream_header",
        first = #output,
        last = #output,
        items = {},
        ignore_sign = true,
        commit = { oid = git.repo.upstream.oid },
      })
    end

    if git.branch.pushRemote_ref() and git.repo.pushRemote.abbrev then
      output:append(
        string.format(
          "Push:     %s%s %s",
          (git.repo.pushRemote.abbrev and git.repo.pushRemote.abbrev .. " ") or "",
          git.branch.pushRemote_ref(),
          git.repo.pushRemote.commit_message or "(does not exist)"
        )
      )

      table.insert(new_locations, {
        name = "push_branch_header",
        first = #output,
        last = #output,
        items = {},
        ignore_sign = true,
        ref = git.branch.pushRemote_ref(),
      })
    end
  end

  if git.repo.head.tag.name then
    output:append(string.format("Tag:      %s (%s)", git.repo.head.tag.name, git.repo.head.tag.distance))
    table.insert(new_locations, {
      name = "tag_header",
      first = #output,
      last = #output,
      items = {},
      ignore_sign = true,
      commit = { oid = git.rev_parse.oid(git.repo.head.tag.name) },
    })
  end

  output:append("")

  local function render_section(header, key, data)
    local section_config = config.values.sections[key]
    if section_config.hidden then
      return
    end

    data = data or git.repo[key]
    if #data.items == 0 then
      return
    end

    if data.current then
      output:append(string.format("%s (%d/%d)", header, data.current, #data.items))
    else
      output:append(string.format("%s (%d)", header, #data.items))
    end

    local location = locations_lookup[key]
      or {
        name = key,
        folded = section_config.folded,
        items = {},
      }
    location.first = #output

    if not location.folded then
      local items_lookup = Collection.new(location.items):key_by("name")
      location.items = {}

      for _, f in ipairs(data.items) do
        local label = util.pad_right(format_mode(f.mode), max_len)
        if label and vim.o.columns < 120 then
          label = vim.trim(label)
        end

        if f.mode and f.original_name then
          output:append(string.format("%s %s -> %s", label, f.original_name, f.name))
        elseif f.mode then
          output:append(string.format("%s %s", label, f.name))
        else
          output:append(f.name)
        end

        if f.done then
          M.status_buffer:place_sign(#output, "NeogitRebaseDone", "hl")
        end

        local file = items_lookup[f.name] or { folded = true }
        file.first = #output

        if not file.folded and f.has_diff then
          local hunks_lookup = Collection.new(file.hunks or {}):key_by("hash")

          local hunks = {}
          for _, h in ipairs(f.diff.hunks) do
            local current_hunk = hunks_lookup[h.hash] or { folded = false }

            output:append(f.diff.lines[h.diff_from])
            current_hunk.first = #output

            if not current_hunk.folded then
              for i = h.diff_from + 1, h.diff_to do
                output:append(f.diff.lines[i])
              end
            end

            current_hunk.last = #output
            table.insert(hunks, setmetatable(current_hunk, { __index = h }))
          end

          file.hunks = hunks
        elseif f.has_diff then
          file.hunks = file.hunks or {}
        end

        file.last = #output
        table.insert(location.items, setmetatable(file, { __index = f }))
      end
    end

    location.last = #output

    if not location.folded then
      output:append("")
    end

    table.insert(new_locations, location)
  end

  if git.repo.rebase.head then
    render_section("Rebasing: " .. git.repo.rebase.head, "rebase")
  elseif git.repo.sequencer.head == "REVERT_HEAD" then
    render_section("Reverting", "sequencer")
  elseif git.repo.sequencer.head == "CHERRY_PICK_HEAD" then
    render_section("Picking", "sequencer")
  end

  render_section("Untracked files", "untracked")
  render_section("Unstaged changes", "unstaged")
  render_section("Staged changes", "staged")
  render_section("Stashes", "stashes")

  local pushRemote = git.branch.pushRemote_ref()
  local upstream = git.branch.upstream()

  if pushRemote and upstream ~= pushRemote then
    render_section(
      string.format("Unpulled from %s", pushRemote),
      "unpulled_pushRemote",
      git.repo.pushRemote.unpulled
    )
    render_section(
      string.format("Unpushed to %s", pushRemote),
      "unmerged_pushRemote",
      git.repo.pushRemote.unmerged
    )
  end

  if upstream then
    render_section(
      string.format("Unpulled from %s", upstream),
      "unpulled_upstream",
      git.repo.upstream.unpulled
    )
    render_section(
      string.format("Unmerged into %s", upstream),
      "unmerged_upstream",
      git.repo.upstream.unmerged
    )
  end

  render_section("Recent commits", "recent")

  M.status_buffer:replace_content_with(output)
  M.locations = new_locations
end

--- Find the smallest section the cursor is contained within.
--
--  The first 3 values are tables in the shape of {number, string}, where the number is
--  the relative offset of the found item and the string is it's identifier.
--  The remaining 2 numbers are the first and last line of the found section.
---@param linenr number|nil
---@return table, table, table, number, number
local function save_cursor_location(linenr)
  local line = linenr or vim.api.nvim_win_get_cursor(0)[1]
  local section_loc, file_loc, hunk_loc, first, last

  for li, loc in ipairs(M.locations) do
    if line == loc.first then
      section_loc = { li, loc.name }
      first, last = loc.first, loc.last

      break
    elseif line >= loc.first and line <= loc.last then
      section_loc = { li, loc.name }

      for fi, file in ipairs(loc.items) do
        if line == file.first then
          file_loc = { fi, file.name }
          first, last = file.first, file.last

          break
        elseif line >= file.first and line <= file.last then
          file_loc = { fi, file.name }

          for hi, hunk in ipairs(file.hunks) do
            if line >= hunk.first and line <= hunk.last then
              hunk_loc = { hi, hunk.hash }
              first, last = hunk.first, hunk.last

              break
            end
          end

          break
        end
      end

      break
    end
  end

  return section_loc, file_loc, hunk_loc, first, last
end

local function restore_cursor_location(section_loc, file_loc, hunk_loc)
  if #M.locations == 0 then
    return vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end

  if not section_loc then
    -- Skip the headers and put the cursor on the first foldable region
    local idx = 1
    for i, location in ipairs(M.locations) do
      if not location.ignore_sign then
        idx = i
        break
      end
    end
    section_loc = { idx, "" }
  end

  local section = Collection.new(M.locations):find(function(s)
    return s.name == section_loc[2]
  end)

  if not section then
    file_loc, hunk_loc = nil, nil
    section = M.locations[section_loc[1]] or M.locations[#M.locations]
  end

  if not file_loc or not section.items or #section.items == 0 then
    return vim.api.nvim_win_set_cursor(0, { section.first, 0 })
  end

  local file = Collection.new(section.items):find(function(f)
    return f.name == file_loc[2]
  end)

  if not file then
    hunk_loc = nil
    file = section.items[file_loc[1]] or section.items[#section.items]
  end

  if not hunk_loc or not file.hunks or #file.hunks == 0 then
    return vim.api.nvim_win_set_cursor(0, { file.first, 0 })
  end

  local hunk = Collection.new(file.hunks):find(function(h)
    return h.hash == hunk_loc[2]
  end) or file.hunks[hunk_loc[1]] or file.hunks[#file.hunks]

  return vim.api.nvim_win_set_cursor(0, { hunk.first, 0 })
end

local function refresh_status_buffer()
  if M.status_buffer == nil then
    return
  end

  M.status_buffer:unlock()

  logger.debug("[STATUS BUFFER]: Redrawing")

  draw_buffer()
  draw_signs()

  logger.debug("[STATUS BUFFER]: Finished Redrawing")

  M.status_buffer:lock()

  vim.cmd("redraw")
end

local refresh_lock = a.control.Semaphore.new(1)

function M.is_refresh_locked()
  return refresh_lock.permits == 0
end

local function get_refresh_lock(reason)
  local permit = refresh_lock:acquire()
  logger.debug(("[STATUS BUFFER]: Acquired refresh lock:"):format(reason or "unknown"))

  vim.defer_fn(function()
    if M.is_refresh_locked() then
      permit:forget()
      logger.debug(
        ("[STATUS BUFFER]: Refresh lock for %s expired after 10 seconds"):format(reason or "unknown")
      )
    end
  end, 10000)

  return permit
end

local function refresh(partial, reason)
  local permit = get_refresh_lock(reason)
  local callback = function()
    local s, f, h = save_cursor_location()
    refresh_status_buffer()

    if M.status_buffer ~= nil and M.status_buffer:is_focused() then
      pcall(restore_cursor_location, s, f, h)
    end

    vim.api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed", modeline = false })

    permit:forget()
    logger.info("[STATUS BUFFER]: Refresh lock is now free")
  end

  git.repo:refresh { source = reason, callback = callback, partial = partial }
end

local dispatch_refresh = a.void(function(partial, reason)
  reason = reason or "unknown"
  if M.is_refresh_locked() then
    logger.debug("[STATUS] Refresh lock is active. Skipping refresh from " .. reason)
  else
    refresh(partial, reason)
  end
end)

local refresh_manually = a.void(function(fname)
  if not fname or fname == "" then
    return
  end

  local path = fs.relpath_from_repository(fname)
  if not path then
    return
  end
  if refresh_lock.permits > 0 then
    refresh({ update_diffs = { "*:" .. path } }, "manually")
  end
end)

--- Compatibility endpoint to refresh data from an autocommand.
--  `fname` should be `<afile>` in this case. This function will take care of
--  resolving the file name to the path relative to the repository root and
--  refresh that file's cache data.
local function refresh_viml_compat(fname)
  logger.info("[STATUS BUFFER]: refresh_viml_compat")
  if not config.values.auto_refresh then
    return
  end
  if #vim.fs.find(".git/", { upward = true }) == 0 then -- not a git repository
    return
  end

  refresh_manually(fname)
end

local function current_line_is_hunk()
  local _, _, h = save_cursor_location()
  return h ~= nil
end

local function toggle()
  local selection = M.get_selection()
  if selection.section == nil then
    return
  end

  local item = selection.item

  local hunks = item and M.get_item_hunks(item, selection.first_line, selection.last_line, false)
  if item and hunks and #hunks > 0 then
    for _, hunk in ipairs(hunks) do
      hunk.hunk.folded = not hunk.hunk.folded
    end

    vim.api.nvim_win_set_cursor(0, { hunks[1].first, 0 })
  elseif item then
    item.folded = not item.folded
  elseif selection.section ~= nil then
    selection.section.folded = not selection.section.folded
  end

  refresh_status_buffer()
end

local reset = function()
  git.repo:reset()
  M.locations = {}
  if not config.values.auto_refresh then
    return
  end
  refresh(nil, "reset")
end

local dispatch_reset = a.void(reset)

local closing = false
local function close(skip_close)
  if closing then
    return
  end
  closing = true

  if skip_close == nil then
    skip_close = false
  end

  M.cursor_location = { save_cursor_location() }

  if not skip_close then
    M.status_buffer:close()
  end

  if M.watcher then
    M.watcher:stop()
  end
  notification.delete_all()
  M.status_buffer = nil
  vim.o.autochdir = M.prev_autochdir
  if M.old_cwd then
    vim.cmd.lcd(M.old_cwd)
  end

  closing = false
end

---@class Selection
---@field sections SectionSelection[]
---@field first_line number
---@field last_line number
---Current items under the cursor
---@field section Section|nil
---@field item StatusItem|nil
---@field commit CommitLogEntry|nil
---
---@field commits  CommitLogEntry[]
---@field items  StatusItem[]
local Selection = {}
Selection.__index = Selection

---@class SectionSelection: Section
---@field section Section
---@field name string
---@field items StatusItem[]

---@return string[], string[]

function Selection:format()
  local lines = {}

  table.insert(lines, string.format("%d,%d:", self.first_line, self.last_line))

  for _, sec in ipairs(self.sections) do
    table.insert(lines, string.format("%s:", sec.name))
    for _, item in ipairs(sec.items) do
      table.insert(lines, string.format("  %s%s:", item == self.item and "*" or "", item.name))
      for _, hunk in ipairs(M.get_item_hunks(item, self.first_line, self.last_line, true)) do
        table.insert(lines, string.format("    %d,%d:", hunk.from, hunk.to))
        for _, line in ipairs(hunk.lines) do
          table.insert(lines, string.format("      %s", line))
        end
      end
    end
  end

  return table.concat(lines, "\n")
end

---@class SelectedHunk: Hunk
---@field from number start offset from the first line of the hunk
---@field to number end offset from the first line of the hunk
---@field conflict boolean true if this hunk contains conflict markers
---@field lines string[]

---@param item StatusItem
---@param first_line number
---@param last_line number
---@param partial boolean
---@return SelectedHunk[]
function M.get_item_hunks(item, first_line, last_line, partial)
  local hunks = {}

  local diff = git.cli.diff.check.call_sync { hidden = true, ignore_error = true }
  local conflict_markers = {}
  if diff.code == 2 then
    for _, out in ipairs(diff.stdout) do
      local line = string.gsub(out, "^" .. item.name .. ":", "")
      if line ~= out and string.match(out, "conflict") then
        table.insert(conflict_markers, tonumber(string.match(line, "%d+")))
      end
    end
  end

  if not item.folded and item.hunks then
    for _, h in ipairs(item.hunks) do
      if h.first <= last_line and h.last >= first_line then
        local from, to

        if partial then
          local cursor_offset = first_line - h.first
          local length = last_line - first_line

          from = h.diff_from + cursor_offset
          to = from + length
        else
          from = h.diff_from + 1
          to = h.diff_to
        end

        local hunk_lines = {}
        for i = from, to do
          table.insert(hunk_lines, item.diff.lines[i])
        end

        local conflict = false
        for _, n in ipairs(conflict_markers) do
          if from <= n and n <= to then
            conflict = true
            break
          end
        end

        local o = {
          from = from,
          to = to,
          __index = h,
          hunk = h,
          conflict = conflict,
          lines = hunk_lines,
        }

        setmetatable(o, o)

        table.insert(hunks, o)
      end
    end
  end

  return hunks
end

---@param selection Selection
function M.selection_hunks(selection)
  local res = {}
  for _, item in ipairs(selection.items) do
    local lines = {}
    local hunks = {}

    for _, h in ipairs(selection.item.hunks) do
      if h.first <= selection.last_line and h.last >= selection.first_line then
        table.insert(hunks, h)
        for i = h.diff_from, h.diff_to do
          table.insert(lines, item.diff.lines[i])
        end
        break
      end
    end

    table.insert(res, {
      item = item,
      hunks = hunks,
      lines = lines,
    })
  end

  return res
end

---Returns the selected items grouped by spanned sections
---@return Selection
function M.get_selection()
  local visual_pos = vim.fn.getpos("v")[2]
  local cursor_pos = vim.fn.getpos(".")[2]

  local first_line = math.min(visual_pos, cursor_pos)
  local last_line = math.max(visual_pos, cursor_pos)

  local res = {
    sections = {},
    first_line = first_line,
    last_line = last_line,
    item = nil,
    commit = nil,
    commits = {},
    items = {},
  }

  for _, section in ipairs(M.locations) do
    local items = {}

    if section.first > last_line then
      break
    end

    if section.last >= first_line then
      if section.first <= first_line and section.last >= last_line then
        res.section = section
      end

      local entire_section = section.first == first_line and first_line == last_line

      for _, item in pairs(section.items) do
        if entire_section or item.first <= last_line and item.last >= first_line then
          if not res.item and item.first <= first_line and item.last >= last_line then
            res.item = item

            res.commit = item.commit
          end

          if item.commit then
            table.insert(res.commits, item.commit)
          end

          table.insert(res.items, item)
          table.insert(items, item)
        end
      end

      local section = {
        section = section,
        items = items,
        __index = section,
      }

      setmetatable(section, section)
      table.insert(res.sections, section)
    end
  end

  return setmetatable(res, Selection)
end

local stage = operation("stage", function()
  local selection = M.get_selection()
  local mode = vim.api.nvim_get_mode()

  local files = {}

  for _, section in ipairs(selection.sections) do
    for _, item in ipairs(section.items) do
      local hunks = M.get_item_hunks(item, selection.first_line, selection.last_line, mode.mode == "V")

      if section.name == "unstaged" then
        if #hunks > 0 then
          for _, hunk in ipairs(hunks) do
            -- Apply works for both tracked and untracked
            local patch = git.index.generate_patch(item, hunk, hunk.from, hunk.to)
            git.index.apply(patch, { cached = true })
          end
        else
          git.status.stage { item.name }
        end
      elseif section.name == "untracked" then
        if #hunks > 0 then
          for _, hunk in ipairs(hunks) do
            -- Apply works for both tracked and untracked
            git.index.apply(git.index.generate_patch(item, hunk, hunk.from, hunk.to), { cached = true })
          end
        else
          table.insert(files, item.name)
        end
      else
        logger.fmt_debug("[STATUS]: Not staging item in %s", section.name)
      end
    end
  end

  --- Add all collected files
  if #files > 0 then
    git.index.add(files)
  end

  refresh({
    update_diffs = vim.tbl_map(function(v)
      return "*:" .. v.name
    end, selection.items),
  }, "stage_finish")
end)

local unstage = operation("unstage", function()
  local selection = M.get_selection()
  local mode = vim.api.nvim_get_mode()

  local files = {}

  for _, section in ipairs(selection.sections) do
    for _, item in ipairs(section.items) do
      if section.name == "staged" then
        local hunks = M.get_item_hunks(item, selection.first_line, selection.last_line, mode.mode == "V")

        if #hunks > 0 then
          for _, hunk in ipairs(hunks) do
            logger.fmt_debug(
              "[STATUS]: Unstaging hunk %d %d of %d %d, index_from %d",
              hunk.from,
              hunk.to,
              hunk.diff_from,
              hunk.diff_to,
              hunk.index_from
            )
            -- Apply works for both tracked and untracked
            git.index.apply(
              git.index.generate_patch(item, hunk, hunk.from, hunk.to, true),
              { cached = true, reverse = true }
            )
          end
        else
          table.insert(files, item.name)
        end
      end
    end
  end

  if #files > 0 then
    git.status.unstage(files)
  end

  refresh({
    update_diffs = vim.tbl_map(function(v)
      return "*:" .. v.name
    end, selection.items),
  }, "unstage_finish")
end)

local function discard_message(files, hunk_count)
  if vim.api.nvim_get_mode() == "V" then
    return "Discard selection?"
  elseif hunk_count > 0 then
    return string.format("Discard %d hunks?", hunk_count)
  elseif #files > 1 then
    return string.format("Discard %d files?", #files)
  else
    return string.format("Discard %q?", files[1])
  end
end

local discard = operation("discard", function()
  local selection = M.get_selection()
  local mode = vim.api.nvim_get_mode()

  git.index.update()

  local t = {}

  local hunk_count = 0
  local file_count = 0
  local files = {}

  for _, section in ipairs(selection.sections) do
    local section_name = section.name

    file_count = file_count + #section.items
    for _, item in ipairs(section.items) do
      table.insert(files, item.name)
      local hunks = M.get_item_hunks(item, selection.first_line, selection.last_line, mode.mode == "V")

      if #hunks > 0 then
        logger.fmt_debug("Discarding %d hunks from %q", #hunks, item.name)

        hunk_count = hunk_count + #hunks

        for _, hunk in ipairs(hunks) do
          table.insert(t, function()
            local patch = git.index.generate_patch(item, hunk, hunk.from, hunk.to, true)
            logger.fmt_debug("Patch: %s", patch)

            if section_name == "staged" then
              --- Apply both to the worktree and the staging area
              git.index.apply(patch, { index = true, reverse = true })
            else
              git.index.apply(patch, { reverse = true })
            end
          end)
        end
      else
        logger.fmt_debug("Discarding in section %s %s", section_name, item.name)
        if item.mode ~= nil and item.mode:match("^[UA][AU]") then
          local choices = { "&ours", "&theirs", "&abort" }
          local choice =
            input.get_choice("Discard conflict by taking...", { values = choices, default = #choices })
          if choice == "o" then
            git.cli.checkout.ours.file(item.absolute_path).call_sync()
          elseif choice == "t" then
            git.cli.checkout.theirs.file(item.absolute_path).call_sync()
          else
            return
          end
          git.status.stage { item.name }
          M.refresh(false, "Resolved conflict")
          return
        end
        table.insert(t, function()
          if section_name == "untracked" then
            a.util.scheduler()
            vim.fn.delete(vim.fn.fnameescape(item.absolute_path))
          elseif section_name == "unstaged" then
            git.index.checkout { item.name }
          elseif section_name == "staged" then
            git.index.reset { item.name }
            git.index.checkout { item.name }
          end
        end)
      end
    end
  end

  if
    not input.get_confirmation(
      discard_message(files, hunk_count),
      { values = { "&Yes", "&No" }, default = 2 }
    )
  then
    return
  end

  for i, v in ipairs(t) do
    logger.fmt_debug("Discard job %d", i)
    v()
  end

  refresh(nil, "discard")

  a.util.scheduler()
  vim.cmd("checktime")
end)

local set_folds = function(to)
  Collection.new(M.locations):each(function(l)
    l.folded = to[1]
    Collection.new(l.items):each(function(f)
      f.folded = to[2]
      if f.hunks then
        Collection.new(f.hunks):each(function(h)
          h.folded = to[3]
        end)
      end
    end)
  end)
  refresh(nil, "set_folds")
end

--- Handles the GoToFile action on sections that contain a hunk
---@param item File
---@see section_has_hunks
local function handle_section_item(item)
  if not item.absolute_path then
    notification.error("Cannot open file. No path found.")
    return
  end

  local row, col
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  local hunk = M.get_item_hunks(item, cursor_row, cursor_row, false)[1]
  if hunk then
    local line_offset = cursor_row - hunk.first
    row = hunk.disk_from + line_offset - 1
    for i = 1, line_offset do
      if string.sub(hunk.lines[i], 1, 1) == "-" then
        row = row - 1
      end
    end
    -- adjust for diff sign column
    col = math.max(0, cursor_col - 1)
  end

  notification.delete_all()
  M.status_buffer:close()

  if not vim.o.hidden and vim.bo.buftype == "" and not vim.bo.readonly and vim.fn.bufname() ~= "" then
    vim.cmd("update")
  end

  local path = vim.fn.fnameescape(vim.fn.fnamemodify(item.absolute_path, ":~:."))
  vim.cmd(string.format("edit %s", path))

  if row and col then
    vim.api.nvim_win_set_cursor(0, { row, col })
  end
end

--- Returns the section header ref the user selected
---@param section Section
---@return string|nil
local function get_header_ref(section)
  if section.name == "head_branch_header" then
    return git.repo.head.branch
  end
  if section.name == "upstream_header" and git.repo.upstream.branch then
    return git.repo.upstream.branch
  end
  if section.name == "tag_header" and git.repo.head.tag.name then
    return git.repo.head.tag.name
  end
  if section.name == "push_branch_header" and git.repo.pushRemote.abbrev then
    return git.repo.pushRemote.abbrev
  end
  return nil
end

--- Determines if a given section is a status header section
---@param section Section
---@return boolean
local function is_section_header(section)
  return vim.tbl_contains(
    { "head_branch_header", "upstream_header", "tag_header", "push_branch_header" },
    section.name
  )
end

--- Determines if a given section contains hunks/diffs
---@param section Section
---@return boolean
local function section_has_hunks(section)
  return vim.tbl_contains({ "unstaged", "staged", "untracked" }, section.name)
end

--- Determines if a given section has a list of commits under it
---@param section Section
---@return boolean
local function section_has_commits(section)
  return vim.tbl_contains({
    "unmerged_pushRemote",
    "unpulled_pushRemote",
    "unmerged_upstream",
    "unpulled_upstream",
    "recent",
    "stashes",
  }, section.name)
end

--- These needs to be a function to avoid a circular dependency
--- between this module and the popup modules
local cmd_func_map = function()
  local mappings = {
    ["Close"] = M.close,
    ["InitRepo"] = a.void(git.init.init_repo),
    ["Depth1"] = a.void(function()
      set_folds { true, true, false }
    end),
    ["Depth2"] = a.void(function()
      set_folds { false, true, false }
    end),
    ["Depth3"] = a.void(function()
      set_folds { false, false, true }
    end),
    ["Depth4"] = a.void(function()
      set_folds { false, false, false }
    end),
    ["Toggle"] = toggle,
    ["Discard"] = { "nv", a.void(discard) },
    ["Stage"] = { "nv", a.void(stage) },
    ["StageUnstaged"] = a.void(function()
      git.status.stage_modified()
      refresh({ update_diffs = true }, "StageUnstaged")
    end),
    ["StageAll"] = a.void(function()
      git.status.stage_all()
      refresh { update_diffs = true }
    end),
    ["Unstage"] = { "nv", a.void(unstage) },
    ["UnstageStaged"] = a.void(function()
      git.status.unstage_all()
      refresh({ update_diffs = true }, "UnstageStaged")
    end),
    ["CommandHistory"] = function()
      GitCommandHistory:new():show()
    end,
    ["Console"] = function()
      local process = require("neogit.process")
      process.show_console()
    end,
    ["TabOpen"] = function()
      local _, item = get_current_section_item()
      if item then
        vim.cmd("tabedit " .. item.name)
      end
    end,
    ["VSplitOpen"] = function()
      local _, item = get_current_section_item()
      if item then
        vim.cmd("vsplit " .. item.name)
      end
    end,
    ["SplitOpen"] = function()
      local _, item = get_current_section_item()
      if item then
        vim.cmd("split " .. item.name)
      end
    end,
    ["YankSelected"] = function()
      local yank

      local selection = require("neogit.status").get_selection()
      if selection.item then
        yank = selection.item.oid or selection.item.name
      elseif selection.commit then
        yank = selection.commit.oid
      elseif selection.section and selection.section.ref then
        yank = selection.section.ref
      elseif selection.section and selection.section.commit then
        yank = selection.section.commit.oid
      end

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
    ["GoToPreviousHunkHeader"] = function()
      local section, item = get_current_section_item()
      if not section then
        return
      end

      local selection = M.get_selection()
      local on_hunk = item and current_line_is_hunk()

      if item and not on_hunk then
        local _, prev_item = get_section_item_for_line(vim.fn.line(".") - 1)
        if prev_item then
          vim.api.nvim_win_set_cursor(0, { prev_item.hunks[#prev_item.hunks].first, 0 })
        end
      elseif on_hunk then
        local hunks = M.get_item_hunks(selection.item, 0, selection.first_line - 1, false)
        local hunk = hunks[#hunks]

        if hunk then
          vim.api.nvim_win_set_cursor(0, { hunk.first, 0 })
          vim.cmd("normal! zt")
        else
          local _, prev_item = get_section_item_for_line(vim.fn.line(".") - 2)
          if prev_item then
            vim.api.nvim_win_set_cursor(0, { prev_item.hunks[#prev_item.hunks].first, 0 })
          end
        end
      end
    end,
    ["GoToNextHunkHeader"] = function()
      local section, item = get_current_section_item()
      if not section then
        return
      end

      local on_hunk = item and current_line_is_hunk()

      if item and not on_hunk then
        vim.api.nvim_win_set_cursor(0, { vim.fn.line(".") + 1, 0 })
      elseif on_hunk then
        local selection = M.get_selection()
        local hunks =
          M.get_item_hunks(selection.item, selection.last_line + 1, selection.last_line + 1, false)

        local hunk = hunks[1]

        assert(hunk, "Hunk is nil")
        assert(item, "Item is nil")

        if hunk.last == item.last then
          local _, next_item = get_section_item_for_line(hunk.last + 1)
          if next_item then
            vim.api.nvim_win_set_cursor(0, { next_item.first + 1, 0 })
          end
        else
          vim.api.nvim_win_set_cursor(0, { hunk.last + 1, 0 })
        end
        vim.cmd("normal! zt")
      end
    end,
    ["GoToFile"] = a.void(function()
      a.util.scheduler()
      local section, item = get_current_section_item()
      if not section then
        return
      end
      if item then
        if section_has_hunks(section) then
          handle_section_item(item)
        else
          if section_has_commits(section) then
            if M.commit_view and M.commit_view.is_open then
              M.commit_view:close()
            end
            M.commit_view = CommitView.new(item.name:match("(.-):? "))
            M.commit_view:open()
          end
        end
      else
        if is_section_header(section) then
          local ref = get_header_ref(section)
          if not ref then
            return
          end
          if M.commit_view and M.commit_view.is_open then
            M.commit_view:close()
          end
          M.commit_view = CommitView.new(ref)
          M.commit_view:open()
        end
      end
    end),

    ["RefreshBuffer"] = function()
      notification.info("Refreshing Status")
      dispatch_refresh(nil, "manual")
    end,
  }

  local popups = require("neogit.popups")
  --- Load the popups from the centralized popup file
  for _, v in ipairs(popups.mappings_table()) do
    --- { name, display_name, mapping }
    if mappings[v[1]] then
      error("Neogit: Mapping '" .. v[1] .. "' is already in use!")
    end

    mappings[v[1]] = v[3]
  end

  return mappings
end

-- Sets decoration provider for buffer
---@param buffer Buffer
---@return nil
local function set_decoration_provider(buffer)
  local decor_ns = api.nvim_create_namespace("NeogitStatusDecor")
  local context_ns = api.nvim_create_namespace("NeogitStatusContext")

  local function on_start()
    return buffer:exists() and buffer:is_focused()
  end

  local function on_win()
    buffer:clear_namespace(decor_ns)
    buffer:clear_namespace(context_ns)

    -- first and last lines of current context based on cursor position, if available
    local _, _, _, first, last = save_cursor_location()
    local cursor_line = vim.fn.line(".")

    for line = fn.line("w0"), fn.line("w$") do
      local text = buffer:get_line(line)[1]
      if text then
        local highlight
        local start = string.sub(text, 1, 1)
        local _, _, hunk, _, _ = save_cursor_location(line)

        if start == head_start then
          highlight = "NeogitHunkHeader"
        elseif line == cursor_line then
          highlight = "NeogitCursorLine"
        elseif start == add_start then
          highlight = "NeogitDiffAdd"
        elseif start == del_start then
          highlight = "NeogitDiffDelete"
        elseif hunk then
          highlight = "NeogitDiffContext"
        end

        if highlight then
          buffer:set_extmark(decor_ns, line - 1, 0, { line_hl_group = highlight, priority = 9 })
        end

        if
          not config.values.disable_context_highlighting
          and first
          and last
          and line >= first
          and line <= last
          and highlight ~= "NeogitCursorLine"
        then
          buffer:set_extmark(
            context_ns,
            line - 1,
            0,
            { line_hl_group = (highlight or "NeogitDiffContext") .. "Highlight", priority = 10 }
          )
        end
      end
    end
  end

  buffer:set_decorations(decor_ns, { on_start = on_start, on_win = on_win })
end

--- Creates a new status buffer
function M.create(kind, cwd)
  kind = kind or config.values.kind

  if M.status_buffer then
    logger.debug("Status buffer already exists. Focusing the existing one")
    M.status_buffer:focus()
    return
  end

  logger.debug("[STATUS BUFFER]: Creating...")

  Buffer.create {
    name = "NeogitStatus",
    filetype = "NeogitStatus",
    kind = kind,
    disable_line_numbers = config.values.disable_line_numbers,
    ---@param buffer Buffer
    initialize = function(buffer, win)
      logger.debug("[STATUS BUFFER]: Initializing...")

      M.status_buffer = buffer

      M.prev_autochdir = vim.o.autochdir

      -- Breaks when initializing a new repo in CWD
      if cwd and win then
        M.old_cwd = vim.fn.getcwd(win)

        vim.api.nvim_win_call(win, function()
          vim.cmd.lcd(cwd)
        end)
      end

      vim.o.autochdir = false

      local mappings = buffer.mmanager.mappings
      local func_map = cmd_func_map()
      local keys = vim.tbl_extend("error", config.values.mappings.status, config.values.mappings.popup)

      for key, val in pairs(keys) do
        if val and val ~= "" then
          local func = func_map[val]

          if func ~= nil then
            if type(func) == "function" then
              mappings.n[key] = func
            elseif type(func) == "table" then
              for _, mode in pairs(vim.split(func[1], "")) do
                mappings[mode][key] = func[2]
              end
            end
          elseif type(val) == "function" then -- For user mappings that are either function values...
            mappings.n[key] = val
          elseif type(val) == "string" then -- ...or VIM command strings
            mappings.n[key] = function()
              vim.cmd(val)
            end
          end
        end
      end

      set_decoration_provider(buffer)

      logger.debug("[STATUS BUFFER]: Dispatching initial render")
      refresh(nil, "Buffer.create")
    end,
    after = function()
      vim.cmd([[setlocal nowrap]])
      M.watcher = watcher.new(git.repo:git_path():absolute())

      if M.cursor_location then
        vim.wait(2000, function()
          return not M.is_refresh_locked()
        end)

        local ok, _ = pcall(restore_cursor_location, unpack(M.cursor_location))
        if ok then
          M.cursor_location = nil
        end
      end
    end,
  }
end

M.toggle = toggle
M.reset = reset
M.dispatch_reset = dispatch_reset
M.refresh = refresh
M.dispatch_refresh = dispatch_refresh
M.refresh_viml_compat = refresh_viml_compat
M.refresh_manually = refresh_manually
M.get_current_section_item = get_current_section_item
M.close = close

function M.enable()
  M.disabled = false
end

function M.disable()
  M.disabled = true
end

function M.get_status()
  return M.status
end

function M.chdir(dir)
  local destination = require("plenary.path").new(dir)
  vim.wait(5000, function()
    return destination:exists()
  end)

  logger.debug("[STATUS] Changing Dir: " .. dir)
  M.old_cwd = dir
  vim.cmd.cd(dir)
  vim.loop.chdir(dir)
  reset()
end

return M
