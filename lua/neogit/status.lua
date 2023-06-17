local Buffer = require("neogit.lib.buffer")
local GitCommandHistory = require("neogit.buffers.git_command_history")
local CommitView = require("neogit.buffers.commit_view")
local git = require("neogit.lib.git")
local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")
local config = require("neogit.config")
local a = require("plenary.async")
local logger = require("neogit.logger")
local Collection = require("neogit.lib.collection")
local F = require("neogit.lib.functional")
local LineBuffer = require("neogit.lib.line_buffer")
local fs = require("neogit.lib.fs")
local input = require("neogit.lib.input")

local map = require("neogit.lib.util").map
local api = vim.api
local fn = vim.fn

local M = {}

M.disabled = false

M.current_operation = nil
M.prev_autochdir = nil
M.status_buffer = nil
M.commit_view = nil

---@class Section
---@field first number
---@field last number
---@field files StatusItem[]
M.locations = {}

M.outdated = {}

---@class StatusItem
---@field name string
---@field first number
---@field last number
---@field oid string|nil optional object id
---@field commit CommitLogEntry|nil optional object id

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

  for i, item in pairs(section.files) do
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

  return section, section.files[item_idx]
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

local max_len = #"Both Modified"

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
    draw_sign_for_item(l, "section")
    if not l.folded then
      Collection.new(l.files):filter(F.dot("hunks")):each(function(f)
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

local function pad_right(s, len)
  return s .. string.rep(" ", math.max(len - #s, 0))
end

local function draw_buffer()
  M.status_buffer:clear_sign_group("hl")
  M.status_buffer:clear_sign_group("fold_markers")

  local output = LineBuffer.new()
  if not config.values.disable_hint then
    output:append("Hint: [<tab>] toggle diff | [s]tage | [u]nstage | [x] discard | [c]ommit | [?] more help")
    output:append("")
  end

  output:append(
    string.format("Head: %s %s", git.repo.head.branch, git.repo.head.commit_message or "(no commits)")
  )

  if git.repo.upstream.ref then
    output:append(
      string.format("Push: %s %s", git.repo.upstream.ref, git.repo.upstream.commit_message or "(no commits)")
    )
  end

  if git.repo.merge.head then
    output:append(string.format("Merge: %s", git.repo.merge.msg or "(no message)"))
  end

  output:append("")

  local new_locations = {}
  local locations_lookup = Collection.new(M.locations):key_by("name")

  local function render_section(header, key)
    local section_config = config.values.sections[key]
    if section_config == false then
      return
    end
    local data = git.repo[key]
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
        files = {},
      }
    location.first = #output

    if not location.folded then
      local files_lookup = Collection.new(location.files):key_by("name")
      location.files = {}

      for _, f in ipairs(data.items) do
        local label = pad_right(format_mode(f.mode), max_len)
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

        local file = files_lookup[f.name] or { folded = true }
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
        table.insert(location.files, setmetatable(file, { __index = f }))
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
  end
  render_section("Untracked files", "untracked")
  render_section("Unstaged changes", "unstaged")
  render_section("Staged changes", "staged")
  render_section("Stashes", "stashes")
  render_section("Unpulled changes", "unpulled")
  render_section("Unmerged changes", "unmerged")
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
  local line = linenr or vim.fn.line(".")
  local section_loc, file_loc, hunk_loc, first, last

  for li, loc in ipairs(M.locations) do
    if line == loc.first then
      section_loc = { li, loc.name }
      first, last = loc.first, loc.last

      break
    elseif line >= loc.first and line <= loc.last then
      section_loc = { li, loc.name }

      for fi, file in ipairs(loc.files) do
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
    return vim.fn.setpos(".", { 0, 1, 0, 0 })
  end
  if not section_loc then
    section_loc = { 1, "" }
  end

  local section = Collection.new(M.locations):find(function(s)
    return s.name == section_loc[2]
  end)
  if not section then
    file_loc, hunk_loc = nil, nil
    section = M.locations[section_loc[1]] or M.locations[#M.locations]
  end
  if not file_loc or not section.files or #section.files == 0 then
    return vim.fn.setpos(".", { 0, section.first, 0, 0 })
  end

  local file = Collection.new(section.files):find(function(f)
    return f.name == file_loc[2]
  end)
  if not file then
    hunk_loc = nil
    file = section.files[file_loc[1]] or section.files[#section.files]
  end
  if not hunk_loc or not file.hunks or #file.hunks == 0 then
    return vim.fn.setpos(".", { 0, file.first, 0, 0 })
  end

  local hunk = Collection.new(file.hunks):find(function(h)
    return h.hash == hunk_loc[2]
  end) or file.hunks[hunk_loc[1]] or file.hunks[#file.hunks]

  vim.fn.setpos(".", { 0, hunk.first, 0, 0 })
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
local lock_holder = nil

local function refresh(which, reason)
  logger.info("[STATUS BUFFER]: Starting refresh")

  if refresh_lock.permits == 0 then
    logger.debug(
      string.format(
        "[STATUS BUFFER]: Refresh lock not available. Aborting refresh. Lock held by: %q",
        lock_holder
      )
    )
    --- Undo the deadlock fix
    --- This is because refresh wont properly wait but return immediately if
    --- refresh is already in progress. This breaks as waiting for refresh does
    --- not mean that a status buffer is drawn and ready
    a.util.scheduler()
    -- refresh_status()
    -- return
  end

  local permit = refresh_lock:acquire()
  lock_holder = reason or "unknown"
  logger.debug("[STATUS BUFFER]: Acquired refresh lock: " .. lock_holder)

  a.util.scheduler()
  local s, f, h = save_cursor_location()

  if cli.git_root() ~= "" then
    git.repo:refresh(which)
    refresh_status_buffer()
    vim.api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed", modeline = false })
  end

  a.util.scheduler()
  if vim.fn.bufname() == "NeogitStatus" then
    restore_cursor_location(s, f, h)
  end

  logger.info("[STATUS BUFFER]: Finished refresh")

  lock_holder = nil
  permit:forget()
  logger.info("[STATUS BUFFER]: Refresh lock is now free")
end

local dispatch_refresh = a.void(function(v, reason)
  refresh(v, reason)
end)

local refresh_manually = a.void(function(fname)
  if not fname or fname == "" then
    return
  end

  local path = fs.relpath_from_repository(fname)
  if not path then
    return
  end
  refresh({ status = true, diffs = { "*:" .. path } }, "manually")
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

local function get_hunk_of_item_for_line(item, line)
  if item.hunks == nil then
    return nil
  end

  local hunk
  local lines = {}
  for _, h in ipairs(item.hunks) do
    if h.first <= line and line <= h.last then
      hunk = h
      for i = hunk.diff_from, hunk.diff_to do
        table.insert(lines, item.diff.lines[i])
      end
      break
    end
  end
  return hunk, lines
end

local function get_current_hunk_of_item(item)
  if item.hunks == nil then
    return nil
  end
  return get_hunk_of_item_for_line(item, vim.fn.line("."))
end

local function toggle()
  local section, item = get_current_section_item()
  if section == nil then
    return
  end

  local on_hunk = item ~= nil and current_line_is_hunk()

  if on_hunk then
    local hunk = get_current_hunk_of_item(item)
    assert(hunk, "Hunk is nil")
    hunk.folded = not hunk.folded
    vim.api.nvim_win_set_cursor(0, { hunk.first, 0 })
  elseif item then
    item.folded = not item.folded
  else
    section.folded = not section.folded
  end

  refresh_status_buffer()
end

local reset = function()
  git.repo:reset()
  M.locations = {}
  if not config.values.auto_refresh then
    return
  end
  refresh(true, "reset")
end

local dispatch_reset = a.void(reset)

local function close(skip_close)
  if not skip_close then
    M.status_buffer:close()
  end
  notif.delete_all()
  M.status_buffer = nil
  vim.o.autochdir = M.prev_autochdir
  if M.cwd_changed then
    vim.cmd("cd -")
  end
end

local function generate_patch_from_selection(item, hunk, from, to, reverse)
  reverse = reverse or false
  from = from or 1
  to = to or hunk.diff_to - hunk.diff_from

  if from > to then
    from, to = to, from
  end
  from = from + hunk.diff_from
  to = to + hunk.diff_from

  local diff_content = {}
  local len_start = hunk.index_len
  local len_offset = 0

  -- + 1 skips the hunk header, since we construct that manually afterwards
  for k = hunk.diff_from + 1, hunk.diff_to do
    local v = item.diff.lines[k]
    local operand, line = v:match("^([+ -])(.*)")

    if operand == "+" or operand == "-" then
      if from <= k and k <= to then
        len_offset = len_offset + (operand == "+" and 1 or -1)
        table.insert(diff_content, v)
      else
        -- If we want to apply the patch normally, we need to include every `-` line we skip as a normal line,
        -- since we want to keep that line.
        if not reverse then
          if operand == "-" then
            table.insert(diff_content, " " .. line)
          end
          -- If we want to apply the patch in reverse, we need to include every `+` line we skip as a normal line, since
          -- it's unchanged as far as the diff is concerned and should not be reversed.
          -- We also need to adapt the original line offset based on if we skip or not
        elseif reverse then
          if operand == "+" then
            table.insert(diff_content, " " .. line)
          end
          len_start = len_start + (operand == "-" and -1 or 1)
        end
      end
    else
      table.insert(diff_content, v)
    end
  end

  local diff_header =
    string.format("@@ -%d,%d +%d,%d @@", hunk.index_from, len_start, hunk.index_from, len_start + len_offset)

  table.insert(diff_content, 1, diff_header)
  table.insert(diff_content, 1, string.format("+++ b/%s", item.name))
  table.insert(diff_content, 1, string.format("--- a/%s", item.name))
  table.insert(diff_content, "\n")
  return table.concat(diff_content, "\n")
end

--- Returns commits in selection
---@return table
local function get_selected_commits()
  local first_line = vim.fn.getpos("v")[2]
  local last_line = vim.fn.getpos(".")[2]

  local items = {}
  for line = first_line, last_line do
    local _, item = get_section_item_for_line(line)
    table.insert(items, item)
  end

  return items
end

---Determines if selection contains multiple files
---@return boolean
local function selection_spans_multiple_items_within_section()
  local first_line = vim.fn.getpos("v")[2]
  local last_line = vim.fn.getpos(".")[2]

  local first_section, first_item = get_section_item_for_line(first_line)
  local last_section, last_item = get_section_item_for_line(last_line)

  if not first_section or not last_section then
    return false
  end

  return (first_section.name == last_section.name) and (first_item.name ~= last_item.name)
end

--- Validates the current selection and acts accordingly
--@return nil
--@return number, number
local function get_selection()
  local first_line = vim.fn.getpos("v")[2]
  local last_line = vim.fn.getpos(".")[2]

  local first_section, first_item = get_section_item_for_line(first_line)
  local last_section, last_item = get_section_item_for_line(last_line)

  if not first_section or not first_item or not last_section or not last_item then
    return nil
  end

  local first_hunk = get_hunk_of_item_for_line(first_item, first_line)
  local last_hunk = get_hunk_of_item_for_line(last_item, last_line)

  if not first_hunk or not last_hunk then
    return nil
  end

  if
    first_section.name ~= last_section.name
    or first_item.name ~= last_item.name
    or first_hunk.first ~= last_hunk.first
  then
    return nil
  end

  first_line = first_line - first_item.first
  last_line = last_line - last_item.first

  -- both hunks are the same anyway so only have to check one
  if first_hunk.diff_from == first_line or first_hunk.diff_from == last_line then
    return nil
  end

  return first_section,
    first_item,
    first_hunk,
    first_line - first_hunk.diff_from,
    last_line - first_hunk.diff_from
end

local stage_selection = function()
  if selection_spans_multiple_items_within_section() then
    git.status.stage(unpack(map(get_selected_commits(), function(item)
      return item.name
    end)))
  else
    local section, item, hunk, from, to = get_selection()
    if section and from then
      local patch = generate_patch_from_selection(item, hunk, from, to)
      cli.apply.cached.with_patch(patch).call()
    end
  end
end

local unstage_selection = function()
  if selection_spans_multiple_items_within_section() then
    git.status.unstage(unpack(map(get_selected_commits(), function(item)
      return item.name
    end)))
  else
    local section, item, hunk, from, to = get_selection()
    if section and from then
      local patch = generate_patch_from_selection(item, hunk, from, to, true)
      cli.apply.reverse.cached.with_patch(patch).call()
    end
  end
end

local stage = function()
  M.current_operation = "stage"
  local section, item = get_current_section_item()
  local mode = vim.api.nvim_get_mode()

  if
    section == nil
    or (section.name ~= "unstaged" and section.name ~= "untracked" and section.name ~= "unmerged")
    or (mode.mode == "V" and item == nil)
  then
    return
  end

  if mode.mode == "V" then
    stage_selection()
  else
    local on_hunk = current_line_is_hunk()
    if item == nil then
      if section.name == "unstaged" then
        git.status.stage_modified()
      elseif section.name == "untracked" then
        local add = git.cli.add
        for i, _ in ipairs(section.files) do
          local item = section.files[i]
          add.files(item.name)
        end
        add.call()
      end
      refresh(true, "stage")
      M.current_operation = nil
      return
    else
      if on_hunk and section.name ~= "untracked" then
        local hunk = get_current_hunk_of_item(item)
        local patch = generate_patch_from_selection(item, hunk)
        cli.apply.cached.with_patch(patch).call()
      else
        git.status.stage(item.name)
      end
    end
  end

  assert(item, "Stage item is nil")
  refresh({ status = true, diffs = { "*:" .. item.name } }, "stage_finish")
  M.current_operation = nil
end

local unstage = function()
  local section, item = get_current_section_item()
  local mode = vim.api.nvim_get_mode()

  if section == nil or section.name ~= "staged" or (mode.mode == "V" and item == nil) then
    return
  end
  M.current_operation = "unstage"

  if mode.mode == "V" then
    unstage_selection()
  else
    if item == nil then
      git.status.unstage_all()
      refresh(true, "unstage")
      M.current_operation = nil
      return
    else
      local on_hunk = current_line_is_hunk()

      if on_hunk then
        local hunk = get_current_hunk_of_item(item)
        local patch = generate_patch_from_selection(item, hunk, nil, nil, true)
        cli.apply.reverse.cached.with_patch(patch).call()
      else
        git.status.unstage(item.name)
      end
    end
  end

  assert(item, "Unstage item is nil")
  refresh({ status = true, diffs = { "*:" .. item.name } }, "unstage_finish")
  M.current_operation = nil
end

local function update_index()
  require("neogit.process")
    .new({ cmd = { "git", "update-index", "-q", "--refresh" }, verbose = true })
    :spawn_async()
end

local function discard_message(item, mode)
  if mode.mode == "V" then
    return "Discard selection?"
  else
    return "Discard '" .. item.name .. "' ?"
  end
end

---Discards selected files
---@param files table
---@param section string
local function discard_selected_files(files, section)
  local filenames = map(files, function(item)
    return item.name
  end)

  logger.debug("[Status] Discarding selected files: " .. table.concat(filenames, ", "))

  if section == "untracked" then
    a.util.scheduler()
    for _, file in ipairs(filenames) do
      vim.fn.delete(cli.git_root() .. "/" .. file)
    end
  elseif section == "unstaged" then
    cli.checkout.files(unpack(filenames)).call()
  elseif section == "staged" then
    cli.reset.files(unpack(filenames)).call()
    cli.checkout.files(unpack(filenames)).call()
  end
end

---Discards selected lines
local function discard_selection(section, item, hunk, from, to)
  logger.debug("Discarding selection hunk:" .. vim.inspect(hunk))
  local patch = generate_patch_from_selection(item, hunk, from, to, true)
  logger.debug("Patch:" .. vim.inspect(patch))

  if section.name == "staged" then
    local result = cli.apply.reverse.index.with_patch(patch).call()
    if result.code ~= 0 then
      error("Failed to discard" .. vim.inspect(result))
    end
  else
    cli.apply.reverse.with_patch(patch).call()
  end
end

---Discards hunk
local function discard_hunk(section, item, lines, hunk)
  lines[1] =
    string.format("@@ -%d,%d +%d,%d @@", hunk.index_from, hunk.index_len, hunk.index_from, hunk.disk_len)

  local diff = table.concat(lines or {}, "\n")
  diff = table.concat({ "--- a/" .. item.name, "+++ b/" .. item.name, diff, "" }, "\n")
  if section == "staged" then
    cli.apply.reverse.index.with_patch(diff).call()
  else
    cli.apply.reverse.with_patch(diff).call()
  end
end

local discard = function()
  local section, item = get_current_section_item()
  if section == nil or item == nil then
    return
  end

  M.current_operation = "discard"

  local mode = vim.api.nvim_get_mode()

  -- These all need to be captured _before_ the get_confirmation() call, since that
  -- seems to effect how vim determines what's selected
  local multi_file = selection_spans_multiple_items_within_section()
  local files = get_selected_commits()

  local selection = { get_selection() }

  local on_hunk = current_line_is_hunk()
  local hunk, lines = get_current_hunk_of_item(item)

  if not input.get_confirmation(discard_message(item, mode), { values = { "&Yes", "&No" }, default = 2 }) then
    return
  end

  -- Make sure the index is in sync as git-status skips it
  -- Do this manually since the `cli` add --no-optional-locks
  update_index()

  if mode.mode == "V" then
    if multi_file then
      discard_selected_files(files, section.name)
    else
      discard_selection(unpack(selection))
    end
  elseif on_hunk then
    discard_hunk(section.name, item, lines, hunk)
  else
    discard_selected_files({ item }, section.name)
  end

  refresh(true, "discard")
  M.current_operation = nil

  a.util.scheduler()
  vim.cmd("checktime")
end

local set_folds = function(to)
  Collection.new(M.locations):each(function(l)
    l.folded = to[1]
    Collection.new(l.files):each(function(f)
      f.folded = to[2]
      if f.hunks then
        Collection.new(f.hunks):each(function(h)
          h.folded = to[3]
        end)
      end
    end)
  end)
  refresh(true, "set_folds")
end

local function cherry_pick()
  local selection = nil
  if vim.api.nvim_get_mode().mode == "V" then
    selection = get_selected_commits()
  end

  require("neogit.popups.cherry_pick").create { commits = selection }
end

--- These needs to be a function to avoid a circular dependency
--- between this module and the popup modules
local cmd_func_map = function()
  return {
    ["Close"] = function()
      M.status_buffer:close()
    end,
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
    ["Discard"] = { "nv", a.void(discard), true },
    ["Stage"] = { "nv", a.void(stage), true },
    ["StageUnstaged"] = a.void(function()
      git.status.stage_modified()
      refresh({ status = true, diffs = true }, "StageUnstaged")
    end),
    ["StageAll"] = a.void(function()
      git.status.stage_all()
      refresh { status = true, diffs = true }
    end),
    ["Unstage"] = { "nv", a.void(unstage), true },
    ["UnstageStaged"] = a.void(function()
      git.status.unstage_all()
      refresh({ status = true, diffs = true }, "UnstageStaged")
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
    ["GoToPreviousHunkHeader"] = function()
      local section, item = get_current_section_item()
      if not section then
        return
      end

      local on_hunk = item and current_line_is_hunk()

      if item and not on_hunk then
        local _, prev_item = get_section_item_for_line(vim.fn.line(".") - 1)
        if prev_item then
          vim.api.nvim_win_set_cursor(0, { prev_item.hunks[#prev_item.hunks].first, 0 })
        end
      elseif on_hunk then
        local hunk = get_current_hunk_of_item(item)

        if hunk and vim.fn.line(".") == hunk.first then
          hunk = get_hunk_of_item_for_line(item, vim.fn.line(".") - 1)
        end

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
        local hunk = get_current_hunk_of_item(item)
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
      -- local repo_root = cli.git_root()
      a.util.scheduler()
      local section, item = get_current_section_item()

      if item and section then
        if section.name == "unstaged" or section.name == "staged" or section.name == "untracked" then
          local path = item.name
          local hunk, hunk_lines = get_current_hunk_of_item(item)
          local cursor_row, cursor_col
          if hunk then
            cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
          end

          notif.delete_all()
          M.status_buffer:close()

          local relpath = vim.fn.fnamemodify(path, ":.")

          if not vim.o.hidden and vim.bo.buftype == "" and not vim.bo.readonly and vim.fn.bufname() ~= "" then
            vim.cmd("update")
          end

          vim.cmd("e " .. relpath)

          if hunk and hunk_lines then
            local line_offset = cursor_row - hunk.first
            local row = hunk.disk_from + line_offset - 1
            for i = 1, line_offset do
              if string.sub(hunk_lines[i], 1, 1) == "-" then
                row = row - 1
              end
            end
            -- adjust for diff sign column
            local col = cursor_col == 0 and 0 or cursor_col - 1
            vim.api.nvim_win_set_cursor(0, { row, col })
          end
        elseif vim.tbl_contains({ "unmerged", "unpulled", "recent", "stashes" }, section.name) then
          if M.commit_view and M.commit_view.is_open then
            M.commit_view:close()
          end
          M.commit_view = CommitView.new(item.name:match("(.-):? "), true)
          M.commit_view:open()
        else
          return
        end
      end
    end),
    ["RefreshBuffer"] = function()
      dispatch_refresh(true)
    end,
    ["HelpPopup"] = function()
      local line = M.status_buffer:get_current_line()

      require("neogit.popups.help").create {
        get_stash = function()
          return {
            name = line[1]:match("^(stash@{%d+})"),
          }
        end,
        use_magit_keybindings = config.values.use_magit_keybindings,
      }
    end,
    ["DiffAtFile"] = function()
      if not config.ensure_integration("diffview") then
        return
      end
      local dv = require("neogit.integrations.diffview")
      local section, item = get_current_section_item()

      if section and item then
        dv.open(section.name, item.name)
      end
    end,
    ["DiffPopup"] = require("neogit.popups.diff").create,
    ["PullPopup"] = require("neogit.popups.pull").create,
    ["RebasePopup"] = require("neogit.popups.rebase").create,
    ["MergePopup"] = require("neogit.popups.merge").create,
    ["PushPopup"] = require("neogit.popups.push").create,
    ["CommitPopup"] = require("neogit.popups.commit").create,
    ["LogPopup"] = require("neogit.popups.log").create,
    ["CherryPickPopup"] = { "nv", a.void(cherry_pick), true },
    ["StashPopup"] = function()
      local line = M.status_buffer:get_current_line()

      require("neogit.popups.stash").create {
        name = line[1]:match("^(stash@{%d+})"),
      }
    end,
    ["BranchPopup"] = require("neogit.popups.branch").create,
    ["FetchPopup"] = require("neogit.popups.fetch").create,
    ["RemotePopup"] = require("neogit.popups.remote").create,
    ["ResetPopup"] = require("neogit.popups.reset").create,
  }
end

-- Sets decoration provider for buffer
---@param buffer Buffer
---@return nil
local function set_decoration_provider(buffer)
  local decor_ns = api.nvim_create_namespace("NeogitStatusDecor")
  local context_ns = api.nvim_create_namespace("NeogitStatusContext")

  local function frame_key()
    return table.concat { fn.line("w0"), fn.line("w$"), fn.getcurpos()[2], buffer:get_changedtick() }
  end

  local last_frame_key = frame_key()

  local function on_start()
    return buffer:is_focused() and frame_key() ~= last_frame_key
  end

  local function on_end()
    last_frame_key = frame_key()
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

  buffer:set_decorations(decor_ns, { on_start = on_start, on_win = on_win, on_end = on_end })
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
    initialize = function(buffer)
      logger.debug("[STATUS BUFFER]: Initializing...")

      M.status_buffer = buffer

      M.prev_autochdir = vim.o.autochdir

      if cwd then
        M.cwd_changed = true
        vim.cmd(string.format("cd %s", cwd))
      end

      vim.o.autochdir = false

      local mappings = buffer.mmanager.mappings
      local func_map = cmd_func_map()

      for key, val in pairs(config.values.mappings.status) do
        if val ~= "" then
          local func = func_map[val]
          if func ~= nil then
            mappings[key] = func
          elseif type(val) == "function" then
            mappings[key] = val
          elseif type(val) == "string" then
            mappings[key] = function()
              vim.cmd(val)
            end
          end
        end
      end

      set_decoration_provider(buffer)

      logger.debug("[STATUS BUFFER]: Dispatching initial render")
      refresh(true, "Buffer.create")
    end,
  }
end

M.toggle = toggle
M.generate_patch_from_selection = generate_patch_from_selection
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

function M.wait_on_current_operation(ms)
  vim.wait(ms or 1000, function()
    return not M.current_operation
  end)
end

return M
