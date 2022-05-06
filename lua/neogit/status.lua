local Buffer = require("neogit.lib.buffer")
local GitCommandHistory = require("neogit.buffers.git_command_history")
local CommitView = require("neogit.buffers.commit_view")
local git = require("neogit.lib.git")
local cli = require('neogit.lib.git.cli')
local notif = require("neogit.lib.notification")
local config = require("neogit.config")
local a = require 'plenary.async'
local logger = require 'neogit.logger'
local repository = require 'neogit.lib.git.repository'
local Collection = require 'neogit.lib.collection'
local F = require 'neogit.lib.functional'
local LineBuffer = require 'neogit.lib.line_buffer'
local fs = require 'neogit.lib.fs'
local input = require 'neogit.lib.input'

local M = {}

M.disabled = false
M.current_operation = nil
M.prev_autochdir = nil
M.repo = repository.create()
M.status_buffer = nil
M.commit_view = nil
M.locations = {}

local hunk_header_matcher = vim.regex('^@@.*@@')
local diff_add_matcher = vim.regex('^+')
local diff_delete_matcher = vim.regex('^-')

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

local function get_section_item_for_line(linenr)
  local section_idx, item_idx = get_section_item_idx_for_line(linenr)
  local section = M.locations[section_idx]

  if section == nil then
    return nil, nil
  end

  return section, section.files[item_idx]
end

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
  R = "Renamed"
}

local function draw_sign_for_item(item, name)
  if item.folded then
    M.status_buffer:place_sign(item.first, "NeogitClosed:"..name, "fold_markers")
  else
    M.status_buffer:place_sign(item.first, "NeogitOpen:"..name, "fold_markers")
  end
end

local function draw_signs()
  if config.values.disable_signs then return end
  for _, l in ipairs(M.locations) do
    draw_sign_for_item(l, 'section')
    if not l.folded then
      Collection.new(l.files)
        :filter(F.dot('hunks'))
        :each(function (f)
          draw_sign_for_item(f, 'item')
          if not f.folded then
            Collection.new(f.hunks):each(function (h)
              draw_sign_for_item(h, 'hunk')
            end)
          end
        end)
    end
  end
end

local function draw_buffer()
  M.status_buffer:clear_sign_group('hl')
  M.status_buffer:clear_sign_group('fold_markers')

  local output = LineBuffer.new()
  if not config.values.disable_hint then
    output:append("Hint: [<tab>] toggle diff | [s]tage | [u]nstage | [x] discard | [c]ommit | [?] more help")
    output:append("")
  end
  output:append(string.format("Head: %s %s", M.repo.head.branch, M.repo.head.commit_message or '(no commits)'))
  if M.repo.upstream.branch then
    output:append(string.format("Push: %s %s", M.repo.upstream.branch, M.repo.upstream.commit_message or '(no commits)'))
  end
  output:append('')

  local new_locations = {}
  local locations_lookup = Collection.new(M.locations):key_by('name')

  local function render_section(header, key)
    local section_config = config.values.sections[key]
    if section_config == false then
      return
    end
    local data = M.repo[key]
    if #data.items == 0 then return end
    output:append(string.format('%s (%d)', header, #data.items))

    local location = locations_lookup[key] or {
      name = key,
      folded = section_config.folded,
      files = {}
    }
    location.first = #output

    if not location.folded then
      local files_lookup = Collection.new(location.files):key_by('name')
      location.files = {}

      for _, f in ipairs(data.items) do
        if f.mode and f.original_name then
          output:append(string.format('%s %s -> %s', mode_to_text[f.mode], f.original_name, f.name))
        elseif f.mode then output:append(string.format('%s %s', mode_to_text[f.mode], f.name))
        else 
          output:append(f.name) 
        end

        local file = files_lookup[f.name] or { folded = true }
        file.first = #output

        if f.diff and not file.folded then
          local hunks_lookup = Collection.new(file.hunks or {}):key_by('hash')

          local hunks = {}
          for _, h in ipairs(f.diff.hunks) do
            local current_hunk = hunks_lookup[h.hash] or { folded = false }

            output:append(f.diff.lines[h.diff_from])
            M.status_buffer:place_sign(#output, 'NeogitHunkHeader', 'hl')
            current_hunk.first = #output

            if not current_hunk.folded then
              for i = h.diff_from + 1, h.diff_to do
                local l = f.diff.lines[i]
                output:append(l)
                if diff_add_matcher:match_str(l) then
                  M.status_buffer:place_sign(#output, 'NeogitDiffAdd', 'hl')
                elseif diff_delete_matcher:match_str(l) then
                  M.status_buffer:place_sign(#output, 'NeogitDiffDelete', 'hl')
                end
              end
            end
            current_hunk.last = #output
            table.insert(hunks, setmetatable(current_hunk, { __index = h }))
          end

          file.hunks = hunks
        elseif f.diff then
          file.hunks = file.hunks or {}
        end

        file.last = #output
        table.insert(location.files, setmetatable(file, { __index = f }))
      end
    end

    location.last = #output
    output:append('')
    table.insert(new_locations, location)
  end

  render_section('Untracked files', 'untracked')
  render_section('Unstaged changes', 'unstaged')
  render_section('Staged changes', 'staged')
  render_section('Stashes', 'stashes')
  render_section('Unpulled changes', 'unpulled')
  render_section('Unmerged changes', 'unmerged')
  render_section('Recent commits', 'recent')

  M.status_buffer:replace_content_with(output)
  M.locations = new_locations
end

--- Find the closest section the cursor is encosed by.
--
-- @return table, table, table, number, number -
--  The first 3 values are tables in the shape of {number, string}, where the number is
--  the relative offset of the found item and the string is it's identifier.
--  The remaining 2 numbers are the first and last line of the found section.
local function save_cursor_location()
  local line = vim.fn.line('.')
  local section_loc, file_loc, hunk_loc, first, last

  for li, loc in ipairs(M.locations) do
    if line == loc.first then
      section_loc = {li, loc.name}
      first, last = loc.first, loc.last
      break
    elseif line >= loc.first and line <= loc.last then
      section_loc = {li, loc.name}
      for fi, file in ipairs(loc.files) do
        if line == file.first then
          file_loc = {fi, file.name}
          first, last = file.first, file.last
          break
        elseif line >= file.first and line <= file.last then
          file_loc = {fi, file.name}
          for hi, hunk in ipairs(file.hunks) do
            if line <= hunk.last then
              hunk_loc = {hi, hunk.hash}
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
  if #M.locations == 0 then return vim.fn.setpos('.', {0, 1, 0, 0}) end
  if not section_loc then 
    section_loc = {1, ''} 
  end

  local section = Collection.new(M.locations):find(function (s) 
    return s.name == section_loc[2] 
  end)
  if not section then
    file_loc, hunk_loc = nil, nil
    section = M.locations[section_loc[1]] or M.locations[#M.locations]
  end
  if not file_loc or not section.files or #section.files == 0 then
    return vim.fn.setpos('.', {0, section.first, 0, 0})
  end

  local file = Collection.new(section.files):find(function (f) 
    return f.name == file_loc[2] 
  end)
  if not file then
    hunk_loc = nil
    file = section.files[file_loc[1]] or section.files[#section.files]
  end
  if not hunk_loc or not file.hunks or #file.hunks == 0 then return vim.fn.setpos('.', {0, file.first, 0, 0}) end

  local hunk = Collection.new(file.hunks):find(function (h) return h.hash == hunk_loc[2] end)
    or file.hunks[hunk_loc[1]]
    or file.hunks[#file.hunks]

  vim.fn.setpos('.', {0, hunk.first, 0, 0})
end

local function refresh_status()
  if M.status_buffer == nil then
    return
  end

  M.status_buffer:unlock()

  logger.debug "[STATUS BUFFER]: Redrawing"

  draw_buffer()
  draw_signs()

  logger.debug "[STATUS BUFFER]: Finished Redrawing"

  M.status_buffer:lock()

  vim.cmd('redraw')
end

local refresh_lock = a.control.Semaphore.new(1)
local function refresh (which)
  which = which or true

  logger.debug "[STATUS BUFFER]: Starting refresh"
  if refresh_lock.permits == 0 then
    logger.debug "[STATUS BUFFER]: Refresh lock not available. Aborting refresh"
    a.util.scheduler()
    refresh_status()
    return
  end

  local permit = refresh_lock:acquire()
  logger.debug "[STATUS BUFFER]: Acquired refresh lock"

  a.util.scheduler()
  local s, f, h = save_cursor_location()

  if cli.git_root() ~= '' then
    if which == true or which.status then
      M.repo:update_status()
      a.util.scheduler()
      refresh_status()
    end

    local refreshes = {}
    if which == true or which.branch_information then
      table.insert(refreshes, function() 
        logger.debug("[STATUS BUFFER]: Refreshing branch information")
        M.repo:update_branch_information() 
      end)
    end
    if which == true or which.stashes then
      table.insert(refreshes, function() 
        logger.debug("[STATUS BUFFER]: Refreshing stash")
        M.repo:update_stashes() 
      end)
    end
    if which == true or which.unpulled then
      table.insert(refreshes, function() 
        logger.debug("[STATUS BUFFER]: Refreshing unpulled commits")
        M.repo:update_unpulled() 
      end)
    end
    if which == true or which.unmerged then
      table.insert(refreshes, function() 
        logger.debug("[STATUS BUFFER]: Refreshing unpushed commits")
        M.repo:update_unmerged() 
      end)
    end
    if which == true or which.recent then
      table.insert(refreshes, function()
        logger.debug("[STATUS BUFFER]: Refreshing recent commits")
        M.repo:update_recent()
      end)
    end
    if which == true or which.diffs then
      local filter = (type(which) == "table" and type(which.diffs) == "table")
        and which.diffs
        or nil

      table.insert(refreshes, function() 
        logger.debug("[STATUS BUFFER]: Refreshing diffs")
        M.repo:load_diffs(filter) 
      end)
    end
    logger.debug(string.format("[STATUS BUFFER]: Running %d refresh(es)", #refreshes))
    a.util.join(refreshes)
    logger.debug "[STATUS BUFFER]: Refreshes completed"
    a.util.scheduler()
    refresh_status()
    vim.cmd [[do <nomodeline> User NeogitStatusRefreshed]]
  end

  a.util.scheduler()
  if vim.fn.bufname() == 'NeogitStatus' then
    restore_cursor_location(s, f, h)
  end

  logger.debug "[STATUS BUFFER]: Finished refresh"
  logger.debug "[STATUS BUFFER]: Refresh lock is now free"
  permit:forget()
end

local dispatch_refresh = a.void(refresh)

local refresh_manually = a.void(function (fname)
  if not fname or fname == "" then return end

  local path = fs.relpath_from_repository(fname)
  if not path then return end
  refresh({ status = true, diffs = { "*:" .. path } })
end)

--- Compatibility endpoint to refresh data from an autocommand.
--  `fname` should be `<afile>` in this case. This function will take care of
--  resolving the file name to the path relative to the repository root and
--  refresh that file's cache data.
local function refresh_viml_compat(fname)
  if not config.values.auto_refresh then return end

  refresh_manually(fname)
end

local function current_line_is_hunk()
  local _,_,h = save_cursor_location()
  return h ~= nil
end

local function get_hunk_of_item_for_line(item, line)
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
    hunk.folded = not hunk.folded
  elseif item then 
    item.folded = not item.folded
  else 
    section.folded = not section.folded 
  end

  refresh_status()
end

local reset = function ()
  M.repo = repository.create()
  M.locations = {}
  if not config.values.auto_refresh then return end
  refresh(true)
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
    vim.cmd "cd -"
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
            table.insert(diff_content, " "..line)
          end
        -- If we want to apply the patch in reverse, we need to include every `+` line we skip as a normal line, since
        -- it's unchanged as far as the diff is concerned and should not be reversed.
        -- We also need to adapt the original line offset based on if we skip or not
        elseif reverse then
          if operand == "+" then
            table.insert(diff_content, " "..line)
          end
          len_start = len_start + (operand == "-" and -1 or 1)
        end
      end
    else
      table.insert(diff_content, v)
    end
  end

  local diff_header = string.format(
                        "@@ -%d,%d +%d,%d @@",
                        hunk.index_from,
                        len_start,
                        hunk.index_from,
                        len_start + len_offset
                      )

  table.insert(diff_content, 1, diff_header)
  table.insert(diff_content, 1, string.format("+++ b/%s", item.name))
  table.insert(diff_content, 1, string.format("--- a/%s", item.name))
  table.insert(diff_content, "\n")
  return table.concat(diff_content, "\n")
end


--- Validates the current selection and acts accordingly
--@return nil
--@return number, number
local function get_selection()
  local first_line = vim.fn.getpos("v")[2]
  local last_line = vim.fn.getpos(".")[2]

  local first_section, first_item = get_section_item_for_line(first_line)
  local last_section, last_item = get_section_item_for_line(last_line)

  if not first_section or
     not first_item or
     not last_section or
     not last_item
  then
    return nil
  end

  local first_hunk = get_hunk_of_item_for_line(first_item, first_line)
  local last_hunk = get_hunk_of_item_for_line(last_item, last_line)

  if not first_hunk or not last_hunk then
    return nil
  end

  if first_section.name ~= last_section.name or
     first_item.name ~= last_item.name or
     first_hunk.first ~= last_hunk.first
  then
    return nil
  end

  first_line = first_line - first_item.first
  last_line = last_line - last_item.first

  -- both hunks are the same anyway so only have to check one
  if first_hunk.diff_from == first_line or
     first_hunk.diff_from == last_line
  then
    return nil
  end

  return first_section, first_item, first_hunk, first_line - first_hunk.diff_from, last_line - first_hunk.diff_from
end

local stage_selection = function()
  local section, item, hunk, from, to = get_selection()
  if section and from then
    local patch = generate_patch_from_selection(item, hunk, from, to)
    cli.apply.cached.with_patch(patch).call()
  end
end

local unstage_selection = function()
  local section, item, hunk, from, to = get_selection()
  if section and from then
    local patch = generate_patch_from_selection(item, hunk, from, to, true)
    cli.apply.reverse.cached.with_patch(patch).call()
  end
end

local stage = function()
  M.current_operation = "stage"
  local section, item = get_current_section_item()
  local mode = vim.api.nvim_get_mode()

  if section == nil
    or (section.name ~= "unstaged" and section.name ~= "untracked" and section.name ~= "unmerged")
    or (mode.mode == "V" and item == nil) then
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
        local add = git.cli.add;
        for i,_ in ipairs(section.files) do
          local item = section.files[i];
          add.files(item.name)
        end
        add.call()
      end
      refresh(true)
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

  refresh({status = true, diffs = {"*:"..item.name}})
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
      git.status.unstage_all(".")
      refresh(true)
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

  refresh({status = true, diffs = {"*:"..item.name}})
  M.current_operation = nil
end

local discard = function()
  local section, item = get_current_section_item()

  if section == nil or item == nil then
    return
  end
  M.current_operation = "discard"

  if not input.get_confirmation("Discard '"..item.name.."' ?", {
    values = { "&Yes", "&No" },
    default = 2
  }) then
    return
  end

  -- TODO: fix nesting
  local mode = vim.api.nvim_get_mode()
  if mode.mode == "V" then
    local section, item, hunk, from, to = get_selection()
    local patch = generate_patch_from_selection(item, hunk, from, to, true)
    if section.name == "staged" then
      cli.apply.reverse.index.with_patch(patch).call()
    else
      cli.apply.reverse.with_patch(patch).call()
    end
  elseif section.name == "untracked" then
    local repo_root = cli.git_root()
    a.util.scheduler()
    vim.fn.delete(repo_root .. '/' .. item.name)
  else

    local on_hunk = current_line_is_hunk()

    if on_hunk then
      local hunk, lines = get_current_hunk_of_item(item)
      lines[1] = string.format('@@ -%d,%d +%d,%d @@', hunk.index_from, hunk.index_len, hunk.index_from, hunk.disk_len)
      local diff = table.concat(lines, "\n")
      diff = table.concat({'--- a/'..item.name, '+++ b/'..item.name, diff, ""}, "\n")
      if section.name == "staged" then
        cli.apply.reverse.index.with_patch(diff).call()
      else
        cli.apply.reverse.with_patch(diff).call()
      end
    elseif section.name == "unstaged" then
      cli.checkout.files(item.name).call()
    elseif section.name == "staged" then
      cli.reset.files(item.name).call()
      cli.checkout.files(item.name).call()
    end

  end

  refresh(true)
  M.current_operation = nil

  a.util.scheduler()
  vim.cmd "checktime"
end

local set_folds = function(to)
  Collection.new(M.locations):each(function (l)
    l.folded = to[1]
    Collection.new(l.files):each(function (f)
      f.folded = to[2]
      if f.hunks then
        Collection.new(f.hunks):each(function (h)
          h.folded = to[3]
        end)
      end
    end)
  end)
  refresh(true)
end


--- These needs to be a function to avoid a circular dependency
--  between this module and the popup modules
local cmd_func_map = function ()
  return {
    ["Close"] = function()
      if M.status_buffer.kind == "tab" then
        vim.cmd "1only"
      end
      vim.cmd "close"
    end,
    ["Depth1"] = a.void(function()
      set_folds({ true, true, false })
    end),
    ["Depth2"] = a.void(function()
      set_folds({ false, true, false })
    end),
    ["Depth3"] = a.void(function()
      set_folds({ false, false, true })
    end),
    ["Depth4"] = a.void(function()
      set_folds({ false, false, false })
    end),
    ["Toggle"] = toggle,
    ["Discard"] = { "nv", a.void(discard), true },
    ["Stage"] = { "nv", a.void(stage), true },
    ["StageUnstaged"] = a.void(function ()
        git.status.stage_modified()
        refresh({status = true, diffs = true})
    end),
    ["StageAll"] = a.void(function()
        git.status.stage_all()
        refresh({status = true, diffs = true})
    end),
    ["Unstage"] = { "nv", a.void(unstage), true },
    ["UnstageStaged"] = a.void(function ()
        git.status.unstage_all()
        refresh({status = true, diffs = true})
    end),
    ["CommandHistory"] = function()
      GitCommandHistory:new():show()
    end,
    ["TabOpen"] = function()
      local _, item = get_current_section_item()
      vim.cmd("tabedit " .. item.name)
    end,
    ["VSplitOpen"] = function()
      local _, item = get_current_section_item()
      vim.cmd("vsplit " .. item.name)
    end,
    ["SplitOpen"] = function()
      local _, item = get_current_section_item()
      vim.cmd("split " .. item.name)
    end,
    ["GoToFile"] = a.void(function()
      local repo_root = cli.git_root()
      a.util.scheduler()
      local section, item = get_current_section_item()

      if item and section then
        if section.name == "unstaged" or section.name == "staged" or section.name == "untracked" then
          local path = item.name
          local hunk = get_current_hunk_of_item(item)

          notif.delete_all()
          M.status_buffer:close()

          local relpath = vim.fn.fnamemodify(repo_root .. '/' .. path, ':.')

          if vim.fn.bufname() ~= "" then
            vim.cmd("w")
          end

          vim.cmd("e " .. relpath)

          if hunk then
            vim.cmd(":" .. hunk.disk_from)
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
    ["RefreshBuffer"] = function() dispatch_refresh(true) end,
    ["HelpPopup"] = function ()
      local line = M.status_buffer:get_current_line()

      require("neogit.popups.help").create { 
        get_stash = function()
          return {
            name = line[1]:match('^(stash@{%d+})') 
          }
        end,
        use_magit_keybindings = config.values.use_magit_keybindings
      }
    end,
    ["DiffAtFile"] = function()
      if not config.ensure_integration 'diffview' then
        return
      end
      local dv = require 'neogit.integrations.diffview'
      local section, item = get_current_section_item()

      if section and item then
        dv.open(section.name, item.name)
      end
    end,
    ["DiffPopup"] = require("neogit.popups.diff").create,
    ["PullPopup"] = require("neogit.popups.pull").create,
    ["RebasePopup"] = require("neogit.popups.rebase").create,
    ["PushPopup"] = require("neogit.popups.push").create,
    ["CommitPopup"] = require("neogit.popups.commit").create,
    ["LogPopup"] = require("neogit.popups.log").create,
    ["StashPopup"] = function ()
      local line = M.status_buffer:get_current_line()

      require("neogit.popups.stash").create { 
        name = line[1]:match('^(stash@{%d+})') 
      }
    end,
    ["BranchPopup"] = require("neogit.popups.branch").create,
  }
end

local function create(kind, cwd)
  kind = kind or config.values.kind

  if M.status_buffer then
    logger.debug "Status buffer already exists. Focusing the existing one"
    M.status_buffer:focus()
    return
  end

  logger.debug "[STATUS BUFFER]: Creating..."

  Buffer.create {
    name = "NeogitStatus",
    filetype = "NeogitStatus",
    kind = kind,
    initialize = function(buffer)
      logger.debug "[STATUS BUFFER]: Initializing..."

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

      logger.debug "[STATUS BUFFER]: Dispatching initial render"
      dispatch_refresh(true)
    end
  }
end

local highlight_group = vim.api.nvim_create_namespace("section-highlight")
local function update_highlight()
  if not M.status_buffer then 
    return
  end
  if config.values.disable_context_highlighting then return end

  vim.api.nvim_buf_clear_namespace(0, highlight_group, 0, -1)
  M.status_buffer:clear_sign_group('ctx')

  local _,_,_, first, last = save_cursor_location()

  if first == nil or last == nil then
    return
  end

  for i=first,last do
    local line = vim.fn.getline(i)
    if hunk_header_matcher:match_str(line) then
      M.status_buffer:place_sign(i, 'NeogitHunkHeaderHighlight', 'ctx')
    elseif diff_add_matcher:match_str(line) then
      M.status_buffer:place_sign(i, 'NeogitDiffAddHighlight', 'ctx')
    elseif diff_delete_matcher:match_str(line) then
      M.status_buffer:place_sign(i, 'NeogitDiffDeleteHighlight', 'ctx')
    else
      M.status_buffer:place_sign(i, 'NeogitDiffContextHighlight', 'ctx')
    end
  end
end

M.create = create
M.toggle = toggle
M.update_highlight = update_highlight
M.generate_patch_from_selection = generate_patch_from_selection
M.reset = reset
M.dispatch_reset = dispatch_reset
M.refresh = refresh
M.dispatch_refresh = dispatch_refresh
M.refresh_viml_compat = refresh_viml_compat
M.refresh_manually = refresh_manually
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
