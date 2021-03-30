local Buffer = require("neogit.lib.buffer")
local GitCommandHistory = require("neogit.buffers.git_command_history")
local git = require("neogit.lib.git")
local cli = require('neogit.lib.git.cli')
local util = require("neogit.lib.util")
local notif = require("neogit.lib.notification")
local config = require("neogit.config")
local a = require'neogit.async'
local repository = require 'neogit.lib.git.repository'

local refreshing = false
local current_operation = nil
local status = {}
local repo = repository.create()
local locations = {}
local status_buffer = nil

local hunk_header_matcher = vim.regex('^@@.*@@')
local diff_add_matcher = vim.regex('^+')
local diff_delete_matcher = vim.regex('^-')

local function line_is_hunk(line)
  -- This returns a false positive on untracked file entries
  return not vim.fn.matchlist(line, "^\\(Added\\|Modified\\|New file\\|Deleted\\|Conflict\\) .*")[1]
end

function StatusFold(lnum)
  local line = vim.fn.getline(lnum)
  if line:match('^Untracked') then return '>1' end -- section headers
  if line:match('^Unstaged') then return '>1' end
  if line:match('^Staged') then return '>1' end
  if line:match('^Unpulled') then return '>1' end
  if line:match('^Unmerged') then return '>1' end
  if line:match('^Modified') then return '>2' end -- file entries
  if line:match('^Renamed') then return '>2' end
  if line:match('^Added') then return '>2' end
  if line:match('^Deleted') then return '>2' end
  if line:match('^Updated') then return '>2' end
  if line:match('^Copied') then return '>2' end
  if line:match('^@@') then return '>3' end -- diff header
  if line:match('^[ +-]') then return 3 end -- diff lines
  if line:match('^%w') then return '=' end -- everything else with text
  return 0
end

local function get_section_idx_for_line(linenr)
  for i, l in pairs(locations) do
    if l.first <= linenr and linenr <= l.last then
      return i
    end
  end
  return nil
end

local function get_location(section_name)
  for _,l in pairs(locations) do
    if l.name == section_name then
      return l
    end
  end
end

local function get_section_item_idx_for_line(linenr)
  local section_idx = get_section_idx_for_line(linenr)
  local section = locations[section_idx]

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
  local section = locations[section_idx]

  if section == nil then
    return nil, nil
  end

  return section, section.files[item_idx]
end

local function get_current_section_item()
  return get_section_item_for_line(vim.fn.line("."))
end

local function toggle_sign_at_line(line)
  local sign_info = status_buffer:get_sign_at_line(line, "fold_markers")
  local sign = sign_info.signs[1]

  if sign ~= nil then
    local parts = vim.split(sign.name, ":")
    local new_name = (parts[1] == "NeogitOpen" and "NeogitClosed" or "NeogitOpen") .. ":" .. parts[2]
    status_buffer:place_sign(line, new_name, 'fold_markers')
  end
end

local function toggle()
  local folded = vim.fn.foldclosed(vim.fn.line('.')) >= 0
  if folded then
    vim.cmd("silent! normal zO")
  else
    vim.cmd("silent! normal zc")
  end

  if not config.values.disable_signs then
    local section, item = get_current_section_item()

    if section == nil then
      return
    end

    local line = item ~= nil and item.first or section.first

    local on_hunk = item ~= nil and line_is_hunk(vim.fn.getline('.'))


    if on_hunk then
      local ignored_sections = { "untracked_files", "stashes", "unpulled", "unmerged" }

      for _, val in pairs(ignored_sections) do
        if val == section.name then
          return
        end
      end

      local hunk = get_current_hunk_of_item(item)
      line = item.first + hunk.first
    end

    toggle_sign_at_line(line)
  end
end

local function new_output()
  return setmetatable({ }, {
    __index = {
      append = function (tbl, data)
        if type(data) == 'string' then table.insert(tbl, data)
        elseif type(data) == 'table' then
          for _, r in ipairs(data) do table.insert(tbl, r) end
        else error('invalid data type') end
        return tbl
      end,
      into_buffer = function (tbl, from, to)
        status_buffer:set_lines(from, to, false, tbl)
      end
    }
  })
end

local mode_to_text = {
  M = "Modified",
  N = "New file",
  A = "Added",
  D = "Deleted",
  C = "Copied",
  U = "Updated",
  R = "Renamed"
}

local size_cache = {
  untracked = {
    files = {}
  },
  unstaged = {
    files = {}
  },
  staged = {
    files = {}
  },
  stashes = {
    files = {}
  },
  unpulled = {
    files = {}
  },
  unmerged = {
    files = {}
  }
}

local function refresh_status()
  if status_buffer == nil then
    return
  end

  status_buffer:unlock()
  status_buffer:clear_sign_group('hl')

  local output = new_output()
  output:append(string.format("Head: %s %s", repo.head.branch, repo.head.commit_message))
  if repo.upstream.branch then
    output:append(string.format("Push: %s %s", repo.upstream.branch, repo.upstream.commit_message))
  end
  output:append('')
  output:into_buffer(0, #output)
  local buffer_offset = #output

  locations = {}

  local function update_section(title, data, key)
    local line = vim.fn.getline(buffer_offset + 1):match('^(.-) %(%d*%)')

    if #data.files == 0 then
      if line and line:match('^'..title) then
        while line ~= '' do
          vim.fn.deletebufline('%', buffer_offset + 1)
          line = vim.fn.getline(buffer_offset + 1)
        end
        vim.fn.deletebufline('%', buffer_offset + 1)
      end
      return
    end

    if line and line:match('^'..title) then
      -- pass
    else
      status_buffer:set_lines(buffer_offset, buffer_offset, false, {string.format('%s (%d)', title, #data.files), ''})
    end

    buffer_offset = buffer_offset + 1
    if not config.values.disable_signs then
      status_buffer:place_sign(buffer_offset, "NeogitOpen:section", "fold_markers")
    end

    local location = {
      name = key,
      first = buffer_offset,
      files = {}
    }

    for _, f in ipairs(data.files) do
      local line = vim.fn.getline(buffer_offset + 1)
      local mode, fname = line:match('^(%w+) (.+)$') -- this check is potentially super dangerous, as it could match on diff lines or section headers just as well
      while line ~= '' and fname and fname < f.name do
        -- file in buffer should come before current file to be rendered, so we can safely remove it
        -- from the buffer.
        vim.fn.deletebufline('%', buffer_offset + 1, buffer_offset + 1 + size_cache[key].files[fname])
        line = vim.fn.getline(buffer_offset + 1)
        mode, fname = line:match('^(%w+) (.+)$')
      end

      local file_matched = line:match(f.name)
      if not file_matched then
        status_buffer:set_lines(buffer_offset, buffer_offset, false, {f.mode and mode_to_text[f.mode]..' '..f.name or f.name})
      end

      buffer_offset = buffer_offset + 1
      if not config.values.disable_signs and f.diff then
        status_buffer:place_sign(buffer_offset, "NeogitClosed:item", "fold_markers")
      end

      local file = { first = buffer_offset, hunks = {}, __file = f }

      if f.diff then
        local cached_size = size_cache[key].files[f.name]
        if file_matched and cached_size then
          status_buffer:set_lines(buffer_offset, buffer_offset + cached_size, false, f.diff.lines)
        else
          status_buffer:set_lines(buffer_offset, buffer_offset, false, f.diff.lines)
        end

        local hunks = {}
        local current_hunk = {}
        local c = buffer_offset + 1
        for _, line in ipairs(f.diff.lines) do
          if hunk_header_matcher:match_str(line) then
            if current_hunk then
              current_hunk.last = c - 1
              table.insert(hunks, current_hunk)
            end
            current_hunk = { first = c }
            status_buffer:place_sign(c, 'NeogitHunkHeader', 'hl')

            if not config.values.disable_signs then
              status_buffer:place_sign(c, "NeogitOpen:hunk", "fold_markers")
            end
          elseif diff_add_matcher:match_str(line) then
            status_buffer:place_sign(c, 'NeogitDiffAdd', 'hl')
          elseif diff_delete_matcher:match_str(line) then
            status_buffer:place_sign(c, 'NeogitDiffDelete', 'hl')
          end
          c = c + 1
        end

        current_hunk.last = c - 1
        table.insert(hunks, current_hunk)
        file.hunks = hunks
        buffer_offset = buffer_offset + #f.diff.lines
        size_cache[key].files[f.name] = #f.diff.lines
      end

      file.last = buffer_offset
      table.insert(location.files, file)
    end

    line = vim.fn.getline(buffer_offset + 1)
    while line ~= '' and buffer_offset < vim.fn.line('$') do
      vim.fn.deletebufline('%', buffer_offset + 1)
      line = vim.fn.getline(buffer_offset + 1)
    end

    if buffer_offset >= vim.fn.line('$') then
      status_buffer:set_lines(buffer_offset, buffer_offset, false, {''})
    end

    location.last = buffer_offset
    table.insert(locations, location)
    buffer_offset = buffer_offset + 1
  end
  update_section('Untracked files', repo.untracked, 'untracked')
  update_section('Unstaged changes', repo.unstaged, 'unstaged')
  update_section('Staged changes', repo.staged, 'staged')
  update_section('Stashes', repo.stashes, 'stashes')
  update_section('Unpulled changes', repo.unpulled, 'unpulled')
  update_section('Unmerged changes', repo.unmerged, 'unmerged')

  status_buffer:set_lines(buffer_offset, -1, false, {})

  status_buffer:lock()

  -- After moving stuff around, the cursor could land IN a fold, so we move
  -- it to the top of the fold to avoid confusion
  -- TODO: maybe store cursor position in a mark, so it can move with the
  -- changes; we could then restore cursor position to the mark.
  local fold_start = vim.fn.foldclosed(vim.fn.line('.'))
  if fold_start >= 0 then vim.fn.setpos('.', {0, fold_start, 0, 0}) end
end

function __NeogitStatusRefresh(force)
  local function wait(ms)
    vim.wait(ms or 1000, function() return not refreshing end)
  end

  if refreshing or (status_buffer ~= nil and not force) then
    return wait
  end

  a.dispatch(function ()
    refreshing = true

    a.wait(repo:update_status())
    a.wait_all({
      repo:update_branch_information(),
      repo:update_stashes(),
      repo:update_unpulled(),
      repo:update_unmerged(),
      repo:load_diffs()
    })
    a.wait_for_textlock()
    refresh_status()

    a.wait_for_textlock()
    vim.cmd [[do <nomodeline> User NeogitStatusRefreshed]]

    refreshing = false
  end)

  return wait
end

function __NeogitStatusOnClose()
  status_buffer = nil
end

function get_hunk_of_item_for_line(item, line)
  local hunk
  local lines = {}
  for _,h in pairs(item.__file.diff.hunks) do
    if item.first + h.first <= line and line <= item.first + h.last then
      hunk = h
      for i=hunk.first,hunk.last do
        table.insert(lines, item.__file.diff.lines[i])
      end
      break
    end
  end
  return hunk, lines
end
function get_current_hunk_of_item(item)
  return get_hunk_of_item_for_line(item, vim.fn.line("."))
end

local function generate_patch_from_selection(item, hunk, from, to, reverse)
  reverse = reverse or false
  from = from or 1
  to = to or hunk.last - hunk.first

  if from > to then
    from, to = to, from
  end
  from = from + hunk.first
  to = to + hunk.first

  local diff_content = {}
  local len_start = hunk.index_len
  local len_offset = 0

  -- + 1 skips the hunk header, since we construct that manually afterwards
  for k = hunk.first + 1, hunk.last do
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

  local diff_header = string.format("@@ -%d,%d +%d,%d @@", hunk.index_from, len_start, hunk.index_from, len_start + len_offset)

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
     first_item.__file.name ~= last_item.__file.name or
     first_hunk.first ~= last_hunk.first
  then
    return nil
  end

  first_line = first_line - first_item.first
  last_line = last_line - last_item.first

  -- both hunks are the same anyway so only have to check one
  if first_hunk.first == first_line or
     first_hunk.first == last_line
  then
    return nil
  end

  return first_section, first_item, first_hunk, first_line - first_hunk.first, last_line - first_hunk.first
end

local stage_selection = a.sync(function()
  local _, item, hunk, from, to = get_selection()
  local patch = generate_patch_from_selection(item.__file, hunk, from, to)
  a.wait(cli.apply.cached.with_patch(patch).call())
end)

local unstage_selection = a.sync(function()
  local _, item, hunk, from, to = get_selection()
  if from == nil then
    return
  end
  local patch = generate_patch_from_selection(item.__file, hunk, from, to, true)
  a.wait(cli.apply.reverse.cached.with_patch(patch).call())
end)

local stage = a.sync(function()
  current_operation = "stage"
  local section, item = get_current_section_item()

  if section == nil or (section.name ~= "unstaged" and section.name ~= "untracked" and section.name ~= "unmerged") or item == nil then
    return
  end

  local mode = vim.api.nvim_get_mode()

  if mode.mode == "V" then
    a.wait(stage_selection())
  else
    local on_hunk = line_is_hunk(vim.fn.getline('.'))

    if on_hunk and section.name ~= "untracked" then
      local hunk = get_current_hunk_of_item(item)
      local patch = generate_patch_from_selection(item.__file, hunk)
      a.wait(cli.apply.cached.with_patch(patch).call())
    else
      a.wait(git.status.stage(item.__file.name))
    end
  end

  __NeogitStatusRefresh(true)
  current_operation = nil
end)

local unstage = a.sync(function()
  current_operation = "unstage"
  local section, item = get_current_section_item()

  if section == nil or section.name ~= "staged" or item == nil then
    return
  end

  local mode = vim.api.nvim_get_mode()

  if mode.mode == "V" then
    a.wait(unstage_selection())
  else
    local on_hunk = line_is_hunk(vim.fn.getline('.'))

    if on_hunk then
      local hunk = get_current_hunk_of_item(item)
      local patch = generate_patch_from_selection(item.__file, hunk, nil, nil, true)
      a.wait(cli.apply.reverse.cached.with_patch(patch).call())
    else
      a.wait(git.status.unstage(item.__file.name))
    end
  end

  __NeogitStatusRefresh(true)
  current_operation = nil
end)

local discard = a.sync(function()
  local section, item = get_current_section_item()

  if section == nil or item == nil then
    return
  end

  local result = vim.fn.confirm("Do you really want to do this?", "&Yes\n&No", 2)
  if result == 2 then
    return
  end

  -- TODO: fix nesting
  local mode = vim.api.nvim_get_mode()
  if mode.mode == "V" then
    local section, item, hunk, from, to = get_selection()
    local patch = generate_patch_from_selection(item, hunk, from, to, true)
    if section.name == "staged_changes" then
      a.wait(cli.apply.reverse.index.with_patch(patch).call())
    else
      a.wait(cli.apply.reverse.with_path(patch).call())
    end
  elseif section.name == "untracked_files" then
    a.wait_for_textlock()
    vim.fn.delete(item.name)
  else

    local on_hunk = line_is_hunk(vim.fn.getline('.'))

    if on_hunk then
      local hunk, lines = get_current_hunk_of_item(item)
      lines[1] = string.format('@@ -%d,%d +%d,%d @@', hunk.index_from, hunk.index_len, hunk.index_from, hunk.disk_len)
      local diff = table.concat(lines, "\n")
      diff = table.concat({'--- a/'..item.name, '+++ b/'..item.name, diff, ""}, "\n")
      if section.name == "staged_changes" then
        a.wait(cli.apply.reverse.index.with_patch(diff).call())
      else
        a.wait(cli.apply.reverse.with_patch(diff).call())
      end
    elseif section.name == "unstaged_changes" then
      a.wait(cli.checkout.files(item.name).call())
    elseif section.name == "staged_changes" then
      a.wait(cli.reset.files(item.name).call())
      a.wait(cli.checkout.files(item.name).call())
    end

  end

  __NeogitStatusRefresh(true)
end)

local cmd_func_map = {
  ["Close"] = function()
    notif.delete_all()
    vim.defer_fn(function ()
      status_buffer:close()
    end, 0)
  end,
  ["Depth1"] = function()
    vim.cmd("set foldlevel=0")
    vim.cmd("norm zz")
  end,
  ["Depth2"] = function()
    vim.cmd("set foldlevel=1")
    vim.cmd("norm zz")
  end,
  ["Depth3"] = function()
    vim.cmd("set foldlevel=1")
    vim.cmd("set foldlevel=2")
    vim.cmd("norm zz")
  end,
  ["Depth4"] = function()
    vim.cmd("set foldlevel=1")
    vim.cmd("set foldlevel=3")
    vim.cmd("norm zz")
  end,
  ["Toggle"] = toggle,
  ["Discard"] = { "nv", function () a.run(discard) end, true },
  ["Stage"] = { "nv", function () a.run(stage) end, true },
  ["StageUnstaged"] = function ()
    a.dispatch(function()
      a.wait(git.status.stage_modified())
      __NeogitStatusRefresh(true)
    end)
  end,
  ["StageAll"] = function ()
    a.dispatch(function()
      a.wait(git.status.stage_all())
      __NeogitStatusRefresh(true)
    end)
  end,
  ["Unstage"] = { "nv", function () a.run(unstage) end, true },
  ["UnstageStaged"] = function ()
    a.dispatch(function()
      a.wait(git.status.unstage_all())
      __NeogitStatusRefresh(true)
    end)
  end,
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
  ["GoToFile"] = function()
    local section, item = get_current_section_item()

    if item ~= nil then
      if section.name ~= "unstaged_changes" and section.name ~= "staged_changes" and section.name ~= "untracked_files" then
        return
      end

      local path = item.name

      notif.delete_all()
      status_buffer:close()

      vim.cmd("e " .. path)
    end
  end,
  ["RefreshBuffer"] = function() __NeogitStatusRefresh(true) end,
  ["HelpPopup"] = function ()
    local pos = vim.fn.getpos('.')
    pos[1] = vim.api.nvim_get_current_buf()
    require("neogit.popups.help").create(pos)
  end,
  ["PullPopup"] = require("neogit.popups.pull").create,
  ["PushPopup"] = require("neogit.popups.push").create,
  ["CommitPopup"] = require("neogit.popups.commit").create,
  ["LogPopup"] = require("neogit.popups.log").create,
  ["StashPopup"] = function ()
    local pos = vim.fn.getpos('.')
    pos[1] = vim.api.nvim_get_current_buf()
    require("neogit.popups.stash").create(pos)
  end,
  ["BranchPopup"] = require("neogit.popups.branch").create,
}

local function create(kind)
  kind = kind or "tab"

  if status_buffer then
    status_buffer:focus()
    return
  end

  Buffer.create {
    name = "NeogitStatus",
    filetype = "NeogitStatus",
    kind = kind,
    initialize = function(buffer)
      status_buffer = buffer

      local mappings = buffer.mmanager.mappings

      for key, val in pairs(config.values.mappings.status) do
        if val ~= "" then
          mappings[key] = cmd_func_map[val]
        end
      end

      vim.cmd('setlocal foldmethod=expr')
      vim.cmd('setlocal foldexpr=v:lua.StatusFold(v:lnum)')

      __NeogitStatusRefresh(true)
    end
  }
end

local highlight_group = vim.api.nvim_create_namespace("section-highlight")
local function update_highlight()
  if config.values.disable_context_highlighting then return end

  vim.api.nvim_buf_clear_namespace(0, highlight_group, 0, -1)
  status_buffer:clear_sign_group('ctx')

  local line = vim.fn.line('.')
  local first, last

  -- This nested madness finds the smallest section the cursor is currently
  -- enclosed by, based on the locations table created while rendering.
  for _,loc in ipairs(locations) do
    if line == loc.first then
      first, last = loc.first, loc.last
      break
    elseif line >= loc.first and line <= loc.last then
      for _,file in ipairs(loc.files) do
        if line == file.first then
          first, last = file.first, file.last
          break
        elseif line >= file.first and line <= file.last then
          for _, hunk in ipairs(file.hunks) do
            if line <= hunk.last then
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

  if first == nil or last == nil then
    return
  end

  for i=first,last do
    local line = vim.fn.getline(i)
    if hunk_header_matcher:match_str(line) then
      status_buffer:place_sign(i, 'NeogitHunkHeaderHighlight', 'ctx')
    elseif diff_add_matcher:match_str(line) then
      status_buffer:place_sign(i, 'NeogitDiffAddHighlight', 'ctx')
    elseif diff_delete_matcher:match_str(line) then
      status_buffer:place_sign(i, 'NeogitDiffDeleteHighlight', 'ctx')
    else
      status_buffer:place_sign(i, 'NeogitDiffContextHighlight', 'ctx')
    end
  end
end

return {
  create = create,
  toggle = toggle,
  update_highlight = update_highlight,
  get_status = function() return status end,
  generate_patch_from_selection = generate_patch_from_selection,
  wait_on_current_operation = function (ms)
    vim.wait(ms or 1000, function() return not current_operation end)
  end,
  wait_on_refresh = function (ms)
    vim.wait(ms or 1000, function() return not refreshing end)
  end
}
