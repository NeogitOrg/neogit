local Buffer = require("neogit.lib.buffer")
local GitCommandHistory = require("neogit.buffers.git_command_history")
local git = require("neogit.lib.git")
local cli = require('neogit.lib.git.cli')
local util = require("neogit.lib.util")
local notif = require("neogit.lib.notification")
local a = require('plenary.async_lib')
local async, await = a.async, a.await

local refreshing = false
local current_operation = nil
local status = {}
local locations = {}
local status_buffer = nil

local hunk_header_matcher = vim.regex('^@@.*@@')
local diff_add_matcher = vim.regex('^+')
local diff_delete_matcher = vim.regex('^-')

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

  for i, item in pairs(status[section.name]) do
    if item.first <= linenr and linenr <= item.last then
      return section_idx, i
    end
  end

  return section_idx, nil
end

local function get_section_item_for_line(linenr)
  local section_idx, item_idx = get_section_item_idx_for_line(linenr)
  local section = locations[section_idx]

  return section, status[section.name][item_idx]
end

local function get_current_section_item()
  return get_section_item_for_line(vim.fn.line("."))
end

local function toggle()
  vim.cmd("silent! normal za")
end

local function change_to_str(change)
  if change.original_name ~= nil then
    return string.format("%s %s -> %s", change.type, change.original_name, change.name)
  else
    return string.format("%s %s", change.type, change.name)
  end
end

local function display_status()
  status_buffer:unlock()
  local old_view = vim.fn.winsaveview()
  status_buffer:clear_sign_group('hl')
  status_buffer:clear()

  if status_buffer == nil then
    return
  end

  locations = {}
  local line_idx = 2
  local output = {
    "Head: " .. status.head.branch .. " " .. status.head.message
  }
  if status.upstream ~= nil then
    line_idx = line_idx + 1
    table.insert(output, "Push: " .. status.upstream.branch .. " " .. status.upstream.message)
  end
  table.insert(output, "")

  local function write(str)
    table.insert(output, str)
    line_idx = line_idx + 1
  end

  local function write_section(options)
    local items

    if options.items == nil then
      items = status[options.name]
    else
      items = options.items
    end

    local len = #items

    if len ~= 0 then
      if type(options.title) == "string" then
        write(string.format("%s (%d)", options.title, len))
      else
        write(options.title())
      end

      local location = {
        name = options.name,
        first = line_idx,
        last = 0,
        files = {}
      }

      for _, item in pairs(items) do
        local name
        local hunks = {}
        local current_hunk

        if options.display then
          name = options.display(item)
        elseif type(item) == "string" then
          name = item
        else
          name = item.name
        end

        write(name)

        if type(item) == "table" then
          item.first = line_idx
        end

        if item.diff_content ~= nil then
          for _, diff_line in ipairs(item.diff_content.lines) do
            write(diff_line)
            if hunk_header_matcher:match_str(diff_line) then
              if current_hunk ~= nil then
                current_hunk.last = line_idx - 1
                table.insert(hunks, current_hunk)
              end
              current_hunk = { first = line_idx }
              status_buffer:place_sign(line_idx, 'NeogitHunkHeader', 'hl')
            elseif diff_add_matcher:match_str(diff_line) then
              status_buffer:place_sign(line_idx, 'NeogitDiffAdd', 'hl')
            elseif diff_delete_matcher:match_str(diff_line) then
              status_buffer:place_sign(line_idx, 'NeogitDiffDelete', 'hl')
            end
          end
          item.diff_open = true
        end


        if type(item) == "table" then
          item.last = line_idx
          if current_hunk ~= nil then
            current_hunk.last = line_idx
            table.insert(hunks, current_hunk)
          end
        end

        table.insert(location.files, {
          first = item.first,
          last = item.last,
          hunks = hunks
        })
      end


      location.last = line_idx
      write("")

      table.insert(locations, location)
    end
  end

  write_section({
    name = "untracked_files",
    title = "Untracked files"
  })
  write_section({
    name = "unstaged_changes",
    title = "Unstaged changes",
    display = change_to_str
  })
  write_section({
    name = "unmerged_changes",
    title = "Unmerged changes",
    display = change_to_str
  })
  write_section({
    name = "staged_changes",
    title = "Staged changes",
    display = change_to_str
  })
  write_section({
    name = "stashes",
    title = "Stashes",
    display = function(stash)
      return "stash@{" .. stash.idx .. "} " .. stash.name
    end
  })
  if status.upstream ~= nil then
    write_section({
      name = "unpulled",
      title = function()
        return "Unpulled from " .. status.upstream.branch .. " (" .. #status.unpulled .. ")"
      end,
    })
    write_section({
      name = "unmerged",
      title = function()
        return "Unmerged into " .. status.upstream.branch .. " (" .. #status.unmerged .. ")"
      end,
    })
  end

  status_buffer:set_lines(0, -1, false, output)
  status_buffer:set_foldlevel(2)

  for _,l in pairs(locations) do
    local items = status[l.name]
    if items ~= nil and l.name ~= "stashes" and l.name ~= "unpulled" and l.name ~= "unmerged" then
      for _, i in pairs(items) do
        if i.diff_content ~= nil then
          for _,h in ipairs(i.diff_content.hunks) do
            status_buffer:create_fold(i.first + h.first, i.first + h.last)
            status_buffer:open_fold(i.first + h.first)
          end
        end
        status_buffer:create_fold(i.first, i.last)
      end
    end
    status_buffer:create_fold(l.first, l.last)
    status_buffer:open_fold(l.first)
  end

  vim.fn.winrestview(old_view)
  status_buffer:lock()
end

function primitive_move_cursor(line)
  for _,l in pairs(locations) do
    if l.first <= line and line <= l.last then
      vim.api.nvim_win_set_cursor(0, { l.first, 0 })
      break
    end
  end
end

--- TODO: rename
--- basically moves the cursor to the next section if the current one has no more items
--@param name of the current section
--@param name of the next section
--@returns whether the function managed to find the next cursor position
function contextually_move_cursor(current, next, item_idx)
  local items = status[current]
  local items_len = #items

  if items_len == 0 then
    local staged_changes = status[next]
    if #staged_changes ~= 0 then
      vim.api.nvim_win_set_cursor(0, { get_location(next).first + 1, 0 })
    end
    return true
  else
    local line = get_location(current).first
    if item_idx > items_len then
      line = line + items_len
    else
      line = line + item_idx
    end
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    return true
  end

  return false
end

local function refresh_status()
  if status_buffer == nil then
    return
  end

  for _,x in ipairs({
    'untracked_files',
    'unstaged_changes',
    'unmerged_changes',
    'staged_changes',
    'unpulled',
    'unmerged',
    'stashes'
  }) do
    for _,i in ipairs(status[x]) do
      i.diff_open = false
    end
  end

  local line = vim.fn.line(".")
  local section_idx = get_section_idx_for_line(line)
  local section = locations[section_idx]

  display_status()

  if section == nil then
    primitive_move_cursor(line)
    return
  end

  local item_idx = line - section.first

  if section.name == "unstaged_changes" then
    if contextually_move_cursor("unstaged_changes", "staged_changes", item_idx) then
      return
    end
  elseif section.name == "staged_changes" then
    if contextually_move_cursor("staged_changes", "unstaged_changes", item_idx) then
      return
    end
  elseif section.name == "untracked_files" then
    if contextually_move_cursor("untracked_files", "staged_changes", item_idx) or
       contextually_move_cursor("untracked_files", "unstaged_changes", item_idx) then
     return
   end
  end
  primitive_move_cursor(line)
end

local load_diffs = async(function ()
  local unstaged = {}
  local staged = {}
  for _,c in pairs(status.unstaged_changes) do
    if c.type ~= "Deleted" and c.type ~= "New file" and not c.diff_open and not c.diff_content then
      table.insert(unstaged, c)
    end
  end
  local unstaged_len = #unstaged
  for _,c in pairs(status.staged_changes) do
    if c.type ~= "Deleted" and c.type ~= "New file" and not c.diff_open and not c.diff_content then
      table.insert(staged, c)
    end
  end

  local cmds = {}
  for _, c in pairs(unstaged) do
    if c.original_name ~= nil then
      table.insert(cmds, cli.diff.files(c.original_name, c.name))
    else
      table.insert(cmds, cli.diff.files(c.name))
    end
  end
  for _, c in pairs(staged) do
    if c.original_name ~= nil then
      table.insert(cmds, cli.diff.cached.files(c.original_name, c.name))
    else
      table.insert(cmds, cli.diff.cached.files(c.name))
    end
  end
  local results = { await(git.cli.in_parallel(unpack(cmds)).call()) }

  for i=1,unstaged_len do
    local name = unstaged[i].name
    for _,c in pairs(status.unstaged_changes) do
      if c.name == name then
        c.diff_content = git.diff.parse(vim.split(results[i], '\n'))
        break
      end
    end
  end
  for i=unstaged_len+1,#results do
    local name = staged[i - unstaged_len].name
    for _,c in pairs(status.staged_changes) do
      if c.name == name then
        c.diff_content = git.diff.parse(vim.split(results[i], '\n'))
        break
      end
    end
  end
end)

function __NeogitStatusRefresh(force)
  local function wait(ms)
    vim.wait(ms or 1000, function() return not refreshing end)
  end

  if refreshing or (status_buffer ~= nil and not force) then
    return wait
  end

  a.scope(function ()
    refreshing = true

    status = await(git.status.get())
    if status ~= nil then
      await(load_diffs())
      await(a.scheduler())
      refresh_status()
    end

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
  for _,h in pairs(item.diff_content.hunks) do
    if item.first + h.first <= line and line <= item.first + h.last then
      hunk = h
      for i=hunk.first,hunk.last do
        table.insert(lines, item.diff_content.lines[i])
      end
      break
    end
  end
  return hunk, lines
end
function get_current_hunk_of_item(item)
  return get_hunk_of_item_for_line(item, vim.fn.line("."))
end

local function add_change(list, item, diff)
  local change = nil
  for _,c in pairs(list) do
    if c.name == item.name then
      change = c
      break
    end
  end

  if change then
    change.diff_content = diff
  else
    local new_item = vim.deepcopy(item)
    new_item.diff_content = diff
    new_item.diff_open = false
    table.insert(list, new_item)
  end
end

local function remove_change(name, item)
  status[name] = util.filter(status[name], function(i)
    return i.name ~= item.name
  end)
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
    local v = item.diff_content.lines[k]
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
  if first_hunk.first == first_line or
     first_hunk.first == last_line
  then
    return nil
  end

  return first_section, first_item, first_hunk, first_line - first_hunk.first, last_line - first_hunk.first
end

local stage_selection = async(function()
  local _, item, hunk, from, to = get_selection()
  local patch = generate_patch_from_selection(item, hunk, from, to)
  await(cli.apply.cached.with_patch(patch).call())
end)

local unstage_selection = async(function()
  local _, item, hunk, from, to = get_selection()
  if from == nil then
    return
  end
  local patch = generate_patch_from_selection(item, hunk, from, to, true)
  await(cli.apply.reverse.cached.with_patch(patch).call())
end)

local function line_is_hunk(line)
  -- This returns a false positive on untracked file entries
  return not vim.fn.matchlist(line, "^\\(Modified\\|New file\\|Deleted\\|Conflict\\) .*")[1]
end

local stage = async(function()
  current_operation = "stage"
  local section, item = get_current_section_item()

  if section == nil or (section.name ~= "unstaged_changes" and section.name ~= "untracked_files" and section.name ~= "unmerged_changes") or item == nil then
    return
  end

  local mode = vim.api.nvim_get_mode()

  if mode.mode == "V" then
    await(stage_selection())
  else

    local on_hunk = line_is_hunk(vim.fn.getline('.'))

    if on_hunk and section.name ~= "untracked_files" then
      local hunk = get_current_hunk_of_item(item)
      local patch = generate_patch_from_selection(item, hunk)
      await(cli.apply.cached.with_patch(patch).call())
    else
      await(git.status.stage(item.name))
    end
  end

  __NeogitStatusRefresh(true)
  current_operation = nil
end)

local unstage = async(function()
  current_operation = "unstage"
  local section, item = get_current_section_item()

  if section == nil or section.name ~= "staged_changes" or item == nil then
    return
  end

  local mode = vim.api.nvim_get_mode()

  if mode.mode == "V" then
    await(unstage_selection())
  else
    local on_hunk = line_is_hunk(vim.fn.getline('.'))

    if on_hunk then
      local hunk = get_current_hunk_of_item(item)
      local patch = generate_patch_from_selection(item, hunk, nil, nil, true)
      await(cli.apply.reverse.cached.with_patch(patch).call())
    else
      await(git.status.unstage(item.name))
    end
  end

  __NeogitStatusRefresh(true)
  current_operation = nil
end)

local discard = async(function()
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
      await(cli.apply.reverse.index.with_patch(patch).call())
    else
      await(cli.apply.reverse.with_path(patch).call())
    end
  elseif section.name == "untracked_files" then
    await(a.scheduler())
    vim.fn.delete(item.name)
  else

    local on_hunk = line_is_hunk(vim.fn.getline('.'))

    if on_hunk then
      local hunk, lines = get_current_hunk_of_item(item)
      lines[1] = string.format('@@ -%d,%d +%d,%d @@', hunk.index_from, hunk.index_len, hunk.index_from, hunk.disk_len)
      local diff = table.concat(lines, "\n")
      diff = table.concat({'--- a/'..item.name, '+++ b/'..item.name, diff, ""}, "\n")
      if section.name == "staged_changes" then
        await(cli.apply.reverse.index.with_patch(diff).call())
      else
        await(cli.apply.reverse.with_patch(diff).call())
      end
    elseif section.name == "unstaged_changes" then
      await(cli.checkout.files(item.name).call())
    elseif section.name == "staged_changes" then
      await(cli.reset.files(item.name).call())
      await(cli.checkout.files(item.name).call())
    end

  end

  __NeogitStatusRefresh(true)
end)

local function create(kind)
  kind = kind or 'tab'
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

      mappings["q"] = function()
        notif.delete_all()
        vim.defer_fn(function ()
          status_buffer:close()
        end, 0)
      end
      mappings["1"] = function()
        vim.cmd("set foldlevel=0")
        vim.cmd("norm zz")
      end
      mappings["2"] = function()
        vim.cmd("set foldlevel=1")
        vim.cmd("norm zz")
      end
      mappings["3"] = function()
        vim.cmd("set foldlevel=1")
        vim.cmd("set foldlevel=2")
        vim.cmd("norm zz")
      end
      mappings["4"] = function()
        vim.cmd("set foldlevel=1")
        vim.cmd("set foldlevel=3")
        vim.cmd("norm zz")
      end
      mappings["tab"] = toggle
      mappings["s"] = { "nv", function () a.run(stage) end, true }
      mappings["S"] = function ()
        a.scope(function()
          for _,c in pairs(status.unstaged_changes) do
            table.insert(status.staged_changes, c)
          end
          status.unstaged_changes = {}
          await(git.status.stage_modified())
          await(a.scheduler())
          refresh_status()
        end)
      end
      mappings["control-s"] = function ()
        a.scope(function()
          for _,c in pairs(status.unstaged_changes) do
            table.insert(status.staged_changes, c)
          end
          for _,c in pairs(status.untracked_files) do
            table.insert(status.staged_changes, c)
          end
          status.unstaged_changes = {}
          status.untracked_files = {}
          await(git.status.stage_all())
          await(a.scheduler())
          refresh_status()
        end)
      end
      mappings["$"] = function()
        GitCommandHistory:new():show()
      end
      mappings["control-r"] = function() __NeogitStatusRefresh(true) end
      mappings["u"] = { "nv", function () a.run(unstage) end, true }
      mappings["U"] = function ()
        a.scope(function()
          for _,c in pairs(status.staged_changes) do
            if c.type == "new file" then
              table.insert(status.untracked_files, c)
            else
              table.insert(status.unstaged_changes, c)
            end
          end
          status.staged_changes = {}
          await(git.status.unstage_all())
          await(a.scheduler())
          refresh_status()
        end)
      end
      mappings["?"] = require("neogit.popups.help").create
      mappings["c"] = require("neogit.popups.commit").create
      mappings["L"] = require("neogit.popups.log").create
      mappings["P"] = require("neogit.popups.push").create
      mappings["p"] = require("neogit.popups.pull").create
      mappings["Z"] = function ()
        require('neogit.popups.stash').create(vim.fn.getpos('.'))
      end
      mappings["x"] = { "nv", function () a.run(discard) end, true }

      __NeogitStatusRefresh(true)
    end
  }
end

local highlight_group = vim.api.nvim_create_namespace("section-highlight")
local function update_highlight()
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
