local Buffer = require("neogit.lib.buffer")
local GitCommandHistory = require("neogit.buffers.git_command_history")
local git = require("neogit.lib.git")
local cli = require('neogit.lib.git.cli')
local util = require("neogit.lib.util")
local notif = require("neogit.lib.notification")
local config = require("neogit.config")
local a = require'neogit.async'
local repository = require 'neogit.lib.git.repository'
local collect = require 'neogit.lib.collection'
local F = require 'neogit.lib.functional'
local LineBuffer = require 'neogit.lib.line_buffer'

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
  if line:match('^stash%@') then return false end
  -- This returns a false positive on untracked file entries
  return not vim.fn.matchlist(line, "^\\(Renamed\\|Added\\|Modified\\|New file\\|Deleted\\|Conflict\\) .*")[1]
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

local mode_to_text = {
  M = "Modified",
  N = "New file",
  A = "Added",
  D = "Deleted",
  C = "Copied",
  U = "Updated",
  R = "Renamed"
}

local function draw_sign_for_item(item, name)
  if item.folded then
    status_buffer:place_sign(item.first, "NeogitClosed:"..name, "fold_markers")
  else
    status_buffer:place_sign(item.first, "NeogitOpen:"..name, "fold_markers")
  end
end

local function draw_signs()
  if config.values.disable_signs then return end
  for _, l in ipairs(locations) do
    draw_sign_for_item(l, 'section')
    if not l.folded then
      collect(l.files)
        :filter(F.dot('hunks'))
        :each(function (f)
          draw_sign_for_item(f, 'item')
          if not f.folded then
            collect(f.hunks):each(function (h)
              draw_sign_for_item(h, 'hunk')
            end)
          end
        end)
    end
  end
end

local function draw_buffer()
  status_buffer:clear_sign_group('hl')
  status_buffer:clear_sign_group('fold_markers')

  local output = LineBuffer.new()
  output:append(string.format("Head: %s %s", repo.head.branch, repo.head.commit_message))
  if repo.upstream.branch then
    output:append(string.format("Push: %s %s", repo.upstream.branch, repo.upstream.commit_message))
  end
  output:append('')

  local new_locations = {}
  local locations_lookup = collect(locations):key_by('name')

  local function render_section(header, data, key)
    if #data.files == 0 then return end
    output:append(string.format('%s (%d)', header, #data.files))

    local location = locations_lookup[key] or {
      name = key,
      folded = false,
      files = {}
    }
    location.first = #output

    if not location.folded then
      local files_lookup = collect(location.files):key_by('name')
      location.files = {}

      for _, f in ipairs(data.files) do
        if f.mode and f.original_name then output:append(string.format('%s %s -> %s', mode_to_text[f.mode], f.original_name, f.name))
        elseif f.mode then output:append(string.format('%s %s', mode_to_text[f.mode], f.name))
        else output:append(f.name) end

        local file = files_lookup[f.name] or { folded = true }
        file.first = #output

        if f.diff and not file.folded then
          local hunks_lookup = collect(file.hunks):key_by('hash')

          local hunks = {}
          for _, h in ipairs(f.diff.hunks) do
            local current_hunk = hunks_lookup[h.hash] or { folded = false }

            output:append(f.diff.lines[h.diff_from])
            status_buffer:place_sign(#output, 'NeogitHunkHeader', 'hl')
            current_hunk.first = #output

            if not current_hunk.folded then
              for i = h.diff_from + 1, h.diff_to do
                local l = f.diff.lines[i]
                output:append(l)
                if diff_add_matcher:match_str(l) then
                  status_buffer:place_sign(#output, 'NeogitDiffAdd', 'hl')
                elseif diff_delete_matcher:match_str(l) then
                  status_buffer:place_sign(#output, 'NeogitDiffDelete', 'hl')
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

  render_section('Untracked files', repo.untracked, 'untracked')
  render_section('Unstaged changes', repo.unstaged, 'unstaged')
  render_section('Staged changes', repo.staged, 'staged')
  render_section('Stashes', repo.stashes, 'stashes')
  render_section('Unpulled changes', repo.unpulled, 'unpulled')
  render_section('Unmerged changes', repo.unmerged, 'unmerged')

  status_buffer:replace_content_with(output)
  locations = new_locations
end

local function refresh_status()
  if status_buffer == nil then
    return
  end

  status_buffer:unlock()

  draw_buffer()
  draw_signs()

  status_buffer:lock()
end

local function toggle()
  local section, item = get_current_section_item()
  if section == nil then
    return
  end

  local on_hunk = item ~= nil and line_is_hunk(vim.fn.getline('.'))

  if on_hunk then
    local hunk = get_current_hunk_of_item(item)
    hunk.folded = not hunk.folded
  elseif item then item.folded = not item.folded
  else section.folded = not section.folded end

  refresh_status()
end

local function reset()
  repo = repository.create()
  locations = {}
  refresh(true)
end
function refresh(force)
  local function wait(ms)
    vim.wait(ms or 1000, function() return not refreshing end)
  end

  if refreshing or (status_buffer ~= nil and not force) then
    return wait
  end

  a.dispatch(function ()
    refreshing = true

    if a.wait(cli.git_root()) ~= '' then
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
      vim.cmd [[do <nomodeline> User NeogitStatusRefreshed]]
    end

    refreshing = false
  end)

  return wait
end

local function close()
  status_buffer = nil
end

function get_hunk_of_item_for_line(item, line)
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
function get_current_hunk_of_item(item)
  return get_hunk_of_item_for_line(item, vim.fn.line("."))
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

local stage_selection = a.sync(function()
  local _, item, hunk, from, to = get_selection()
  local patch = generate_patch_from_selection(item, hunk, from, to)
  a.wait(cli.apply.cached.with_patch(patch).call())
end)

local unstage_selection = a.sync(function()
  local _, item, hunk, from, to = get_selection()
  if from == nil then
    return
  end
  local patch = generate_patch_from_selection(item, hunk, from, to, true)
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
      local patch = generate_patch_from_selection(item, hunk)
      a.wait(cli.apply.cached.with_patch(patch).call())
    else
      a.wait(git.status.stage(item.name))
    end
  end

  refresh(true)
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
      local patch = generate_patch_from_selection(item, hunk, nil, nil, true)
      a.wait(cli.apply.reverse.cached.with_patch(patch).call())
    else
      a.wait(git.status.unstage(item.name))
    end
  end

  refresh(true)
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
      a.wait(cli.apply.reverse.with_patch(patch).call())
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

  refresh(true)
end)

local function set_folds(to)
  collect(locations):each(function (l)
    l.folded = to[1]
    collect(l.files):each(function (f)
      f.folded = to[2]
      if f.hunks then
        collect(f.hunks):each(function (h)
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
      notif.delete_all()
      vim.defer_fn(function ()
        status_buffer:close()
      end, 0)
    end,
    ["Depth1"] = function()
      set_folds({ true, true, false })
    end,
    ["Depth2"] = function()
      set_folds({ false, false, true })
    end,
    ["Depth3"] = function()
      set_folds({ false, false, false })
    end,
    ["Toggle"] = toggle,
    ["Discard"] = { "nv", function () a.run(discard) end, true },
    ["Stage"] = { "nv", function () a.run(stage) end, true },
    ["StageUnstaged"] = function ()
      a.dispatch(function()
        a.wait(git.status.stage_modified())
        refresh(true)
      end)
    end,
    ["StageAll"] = function ()
      a.dispatch(function()
        a.wait(git.status.stage_all())
        refresh(true)
      end)
    end,
    ["Unstage"] = { "nv", function () a.run(unstage) end, true },
    ["UnstageStaged"] = function ()
      a.dispatch(function()
        a.wait(git.status.unstage_all())
        refresh(true)
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
    ["RefreshBuffer"] = function() refresh(true) end,
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
end

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
      local func_map = cmd_func_map()

      for key, val in pairs(config.values.mappings.status) do
        if val ~= "" then
          mappings[key] = func_map[val]
        end
      end

      refresh(true)
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
  end,
  reset = reset,
  refresh = refresh,
  close = close
}
