local buffer = require("neogit.buffer")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local notif = require("neogit.lib.notification")
local mappings_manager = require("neogit.lib.mappings_manager")

local status = {}
local locations = {}
local buf_handle = nil

local function get_current_section_idx()
  local linenr = vim.fn.line(".")
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

local function get_current_section()
  return locations[get_current_section_idx()]
end

local function get_current_section_item()
  local linenr = vim.fn.line(".")
  local section = get_current_section()

  for _, item in pairs(status[section.name]) do
    if item.first <= linenr and linenr <= item.last then
      return item
    end
  end
  return nil
end

local function empty_buffer()
  vim.api.nvim_buf_set_lines(buf_handle, 0, -1, false, {})
end

local function insert_diff(section, change)
  vim.api.nvim_command("normal zd")

  if not change.diff_content then
    if section.name == "staged_changes" then
      change.diff_content = git.diff.staged(change.name)
    else
      change.diff_content = git.diff.unstaged(change.name)
    end
  end

  change.diff_open = true
  change.diff_height = #change.diff_content.lines

  for _, c in pairs(status[section.name]) do
    if c.first > change.last then
      c.first = c.first + change.diff_height
      c.last = c.last + change.diff_height
    end
  end

  for _, s in pairs(locations) do
    if s.first > section.last then
      s.first = s.first + change.diff_height
      s.last = s.last + change.diff_height
      for _, c in pairs(status[s.name]) do
        if c.first > change.last then
          c.first = c.first + change.diff_height
          c.last = c.last + change.diff_height
        end
      end
    end
  end

  change.last = change.first + change.diff_height
  section.last = section.last + change.diff_height

  buffer.modify(function()
    vim.api.nvim_put(change.diff_content.lines, "l", true, false)
  end)

  for _, hunk in pairs(change.diff_content.hunks) do
    util.create_fold(0, change.first + hunk.first, change.first + hunk.last)
  end

  util.create_fold(0, change.first, change.last)
end

local function insert_diffs()
  local function insert(name)
    local location = get_location(name)
    for _,c in pairs(status[name]) do
      if not c.diff_open then
        vim.api.nvim_win_set_cursor(0, { c.first, 0 })
        insert_diff(location, c)
      end
    end
  end
  insert("unstaged_changes")
  insert("staged_changes")
end

local function toggle()
  local linenr = vim.fn.line(".")
  local line = vim.fn.getline(linenr)
  local matches = vim.fn.matchlist(line, "^modified \\(.*\\)")
  if #matches ~= 0 then
    local section = get_current_section()
    local change = get_current_section_item()

    if change.diff_open then
      vim.api.nvim_command("normal za")
      return
    end

    insert_diff(section, change)

    vim.api.nvim_command("normal zO")
    vim.cmd("norm k")
  else
    vim.api.nvim_command("normal za")
  end
end

local function change_to_str(change)
  return string.format("%s %s", change.type, change.name)
end

local function display_status()
  locations = {}

  local line_idx = 3
  local output = {
    "Head: " .. status.branch,
    "Push: " .. status.remote,
    ""
  }

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
        last = 0
      }

      for _, item in pairs(items) do
        local name = item.name

        if options.display then
          name = options.display(item)
        elseif type(item) == "string" then
          name = item
        end

        write(name)

        if type(item) == "table" then
          item.first = line_idx
          item.last = line_idx
        end
      end

      write("")

      location.last = line_idx

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
  write_section({
    name = "unpulled",
    title = function()
      return "Unpulled from " .. status.remote .. " (" .. #status.unpulled .. ")"
    end,
  })
  write_section({
    name = "unmerged",
    title = function()
      return "Unmerged into " .. status.remote .. " (" .. #status.unmerged .. ")"
    end,
  })

  vim.api.nvim_buf_set_lines(buf_handle, 0, -1, false, output)

  for _,l in pairs(locations) do
    local items = status[l.name]
    if items ~= nil then
      for _, i in pairs(items) do
        util.create_fold(buf_handle, i.first, i.last)
      end
    end
    util.create_fold(buf_handle, l.first, l.last)
  end
  vim.cmd("set foldlevel=1")
end

local function refresh_status()
  for _,x in pairs(status) do
    if type(x) == "table" then
      for _,i in pairs(x) do
        i.diff_open = false
      end
    end
  end

  buffer.modify(function()
    empty_buffer()

    display_status()
  end)

  print("Refreshed status!")
end

function load_diffs()
  local unstaged = {}
  local staged = {}
  for _,c in pairs(status.unstaged_changes) do
    if not c.diff_open and not c.diff_content then
      table.insert(unstaged, c.name)
    end
  end
  local unstaged_len = #unstaged
  for _,c in pairs(status.staged_changes) do
    if not c.diff_open and not c.diff_content then
      table.insert(staged, c.name)
    end
  end
  local cmds = {}
  for _, c in pairs(unstaged) do
    table.insert(cmds, "diff " .. c)
  end
  for _, c in pairs(staged) do
    table.insert(cmds, "diff --cached " .. c)
  end
  local results = git.cli.run_batch(cmds)

  for i=1,#results do
    if i <= unstaged_len then
      local name = unstaged[i]
      for _,c in pairs(status.unstaged_changes) do
        if c.name == name then
          c.diff_content = git.diff.parse(results[i])
          break
        end
      end
    else
      local name = staged[i - unstaged_len]
      for _,c in pairs(status.staged_changes) do
        if c.name == name then
          c.diff_content = git.diff.parse(results[i])
          break
        end
      end
    end
  end
end

function __NeogitStatusRefresh()
  status = git.status.get()
  refresh_status()
end

function __NeogitStatusOnClose()
  buf_handle = nil
end

local function stage()
  local section = get_current_section()

  if section == nil or (section.name ~= "unstaged_changes" and section.name ~= "untracked_files") then
    return
  end

  local item = get_current_section_item()

  if item == nil then
    return
  end

  local line = vim.fn.line('.')
  local on_hunk = not vim.fn.matchlist(vim.fn.getline('.'), "^\\(modified\\|new file\\|deleted\\) .*")[1]

  if on_hunk then
    local hunk
    for _,h in pairs(item.diff_content.hunks) do
      if item.first + h.first <= line and line <= item.first + h.last then
        hunk = h
        break
      end
    end
    print(item.name, hunk.from, hunk.to)
    git.status.stage_range(
      item.name,
      vim.api.nvim_buf_get_lines(buf_handle, item.first + hunk.first, item.first + hunk.last, false),
      hunk.from,
      hunk.to
    )
  else
  end

  -- status[section.name] = util.filter(status[section.name], function(i)
  --   return i.name ~= item.name
  -- end)

  -- local change = nil
  -- for _,c in pairs(status.staged_changes) do
  --   if c.name == item.name then
  --     change = c
  --     break
  --   end
  -- end

  -- if change then
  --   change.diff_content = nil
  -- else
  --   table.insert(status.staged_changes, item)
  -- end

  -- git.status.stage(item.name)

  -- if change then
  --   change.diff_content = git.diff.staged(change.name)
  -- end

  -- refresh_status()
end

local function unstage()
  local section = get_current_section()

  if section == nil or section.name ~= "staged_changes" then
    return
  end

  local item = get_current_section_item()

  if item == nil then
    return
  end

  status[section.name] = util.filter(status[section.name], function(i)
    return i.name ~= item.name
  end)

  local change = nil
  if item.type == "new file" then
    for _,c in pairs(status.untracked_files) do
      if c.name == item.name then
        change = c
        break
      end
    end
  else
    for _,c in pairs(status.unstaged_changes) do
      if c.name == item.name then
        change = c
        break
      end
    end
  end

  if change then
    change.diff_content = nil
  else
    if item.type == "new file" then
      table.insert(status.untracked_files, item)
    else
      table.insert(status.unstaged_changes, item)
    end
  end

  git.status.unstage(item.name)

  if change then
    change.diff_content = git.diff.unstaged(change.name)
  end

  refresh_status()
end

local function create()
  util.time("Creating NeogitStatus", function()
    if buf_handle then
      buffer.go_to(buf_handle)
    end
    buf_handle = buffer.create({
      name = "NeogitStatus",
      tab = true,
      initialize = function()
        vim.api.nvim_command("setlocal foldmethod=manual")
        vim.api.nvim_command([[
        function! FoldFunction()
          return getline(v:foldstart)
        endfunction
        ]])
        vim.api.nvim_command("setlocal fillchars=fold:\\ ")
        vim.api.nvim_command("setlocal foldminlines=0")
        vim.api.nvim_command("setlocal foldtext=FoldFunction()")
        vim.api.nvim_command("hi Folded guibg=None guifg=None")

        status = git.status.get()
        display_status()

        vim.fn.matchadd("Macro", "^Head: \\zs.*")
        vim.fn.matchadd("SpecialChar", "^Push: \\zs.*")

        vim.fn.matchadd("Function", "^Untracked files\\ze (")
        vim.fn.matchadd("Function", "^Unstaged changes\\ze (")
        vim.fn.matchadd("Function", "^Staged changes\\ze (")
        vim.fn.matchadd("Function", "^Stashes\\ze (")

        vim.fn.matchadd("Function", "^Unmerged into\\ze .* (")
        vim.fn.matchadd("SpecialChar", "^Unmerged into \\zs.*\\ze (")

        vim.fn.matchadd("Function", "^Unpulled from\\ze .* (")
        vim.fn.matchadd("SpecialChar", "^Unpulled from \\zs.*\\ze (")

        vim.fn.matchadd("Comment", "^[a-z0-9]\\{7}\\ze ")
        vim.fn.matchadd("Comment", "^stash@{[0-9]*}\\ze ")

        vim.fn.matchadd("DiffAdd", "^+.*")
        vim.fn.matchadd("DiffDelete", "^-.*")

        -- vim.fn.matchadd("DiffAdd", "^new file\\ze")
        -- vim.fn.matchadd("DiffDelete", "^deleted\\ze")
        -- vim.fn.matchadd("DiffChange", "^modified\\ze")
        local mmanager = mappings_manager.new()

        mmanager.mappings["1"] = function()
          vim.cmd("set foldlevel=0")
          vim.cmd("norm zz")
        end
        mmanager.mappings["2"] = function()
          vim.cmd("set foldlevel=1")
          vim.cmd("norm zz")
        end
        mmanager.mappings["3"] = function()
          vim.cmd("set foldlevel=1")
          insert_diffs()
          vim.cmd("set foldlevel=2")
          vim.cmd("norm zz")
        end
        mmanager.mappings["4"] = function()
          vim.cmd("set foldlevel=1")
          insert_diffs()
          vim.cmd("set foldlevel=3")
          vim.cmd("norm zz")
        end
        mmanager.mappings["tab"] = toggle
        mmanager.mappings["s"] = stage
        mmanager.mappings["S"] = function()
          for _,c in pairs(status.unstaged_changes) do
            table.insert(status.staged_changes, c)
          end
          status.unstaged_changes = {}
          git.status.stage_modified()
          refresh_status()
        end
        mmanager.mappings["control-s"] = function()
          for _,c in pairs(status.unstaged_changes) do
            table.insert(status.staged_changes, c)
          end
          for _,c in pairs(status.untracked_files) do
            table.insert(status.staged_changes, c)
          end
          status.unstaged_changes = {}
          status.untracked_files = {}
          git.status.stage_all()
          refresh_status()
        end
        mmanager.mappings["control-r"] = __NeogitStatusRefresh
        mmanager.mappings["u"] = unstage
        mmanager.mappings["U"] = function()
          for _,c in pairs(status.staged_changes) do
            if c.type == "new file" then
              table.insert(status.untracked_files, c)
            else
              table.insert(status.unstaged_changes, c)
            end
          end
          status.staged_changes = {}
          refresh_status()
        end
        mmanager.mappings["c"] = require("neogit.popups.commit").create
        mmanager.mappings["l"] = require("neogit.popups.log").create
        mmanager.mappings["P"] = require("neogit.popups.push").create

        mmanager.register()

        vim.cmd("au BufWipeout <buffer> lua __NeogitStatusOnClose()")

        vim.defer_fn(load_diffs, 0)
      end
    })
  end)
end

create()

return {
  create = create,
  toggle = toggle
}
