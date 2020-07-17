local buffer = require("neogit.buffer")
local git = require("neogit.git")
local util = require("neogit.lib.util")

local mappings = {}
local status = {}
local locations = {}

local function get_current_section()
  local linenr = vim.fn.line(".")
  for _, l in pairs(locations) do
    if l.first <= linenr and linenr <= l.last then
      return l
    end
  end
  return nil
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
  vim.api.nvim_command("norm ggVGzd")
  vim.api.nvim_command("1,$delete")
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

    vim.api.nvim_command("normal zd")

    local diff = git.diff({ name = change.name, cache = section.name == "staged_changes"})

    change.diff_open = true
    change.diff_height = #diff.lines

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
      vim.api.nvim_put(diff.lines, "l", true, false)
    end)

    for _, hunk in pairs(diff.hunks) do
      util.create_fold(change.first + hunk.first, change.first + hunk.last)
    end

    util.create_fold(change.first, change.last)
    vim.api.nvim_command("normal zO")
  else
    vim.api.nvim_command("normal za")
  end
end

local function change_to_str(change)
  return string.format("%s %s", change.type, change.name)
end

local function display_status()
  locations = {}

  status = git.parse_status(git.cli("status"))
  status.stashes = git.parse_stashes(git.cli("stash list"))

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
  if status.behind_by ~= 0 then
    status.unpulled = util.map(git.cli(string.format("log --oneline ..%s", status.remote)), function(i)
      return {
        name = i
      }
    end)
    write_section({
      name = "unpulled",
      title = function()
        return "Unpulled from " .. status.remote .. " (" .. status.behind_by .. ")"
      end,
    })
  end
  if status.ahead_by ~= 0 then
    status.unmerged = util.map(git.cli(string.format("log --oneline %s..", status.remote)), function(i)
      return {
        name = i
      }
    end)
    write_section({
      name = "unmerged",
      title = function()
        return "Unmerged into " .. status.remote .. " (" .. status.ahead_by .. ")"
      end,
    })
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, output)

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

  for _,l in pairs(locations) do
    local items = status[l.name]
    if items ~= nil then
      for _, i in pairs(items) do
        util.create_fold(i.first, i.last)
      end
    end
    util.create_fold(l.first, l.last)
  end

  vim.api.nvim_command("set foldlevel=1")
end

local function refresh_status()
  buffer.modify(function()
    local cursor = vim.api.nvim_win_get_cursor(0)

    empty_buffer()

    display_status()

    vim.api.nvim_win_set_cursor(0, cursor)
  end)
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

  git.stage(item.name)

  refresh_status()
end

local function unstage()
  local section = get_current_section()

  if section == nil or section.name ~= "staged_changes" then
    return
  end

  local item = get_current_section_item()

  git.unstage(item.name)

  refresh_status()
end

local function create()
  if buffer.exists("NeogitStatus") then
    buffer.go_to("NeogitStatus")
    return
  end
  buffer.create({
    name = "NeogitStatus",
    tab = true,
    initialize = function(buf_handle)
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

      mappings["tab"] = toggle
      mappings["s"] = stage
      mappings["S"] = function()
        git.stage_modified()
        refresh_status()
      end
      mappings["control s"] = function()
        git.stage_all()
        refresh_status()
      end
      mappings["u"] = unstage
      mappings["U"] = function()
        git.unstage_all()
        refresh_status()
      end
      mappings["c"] = require("neogit.popups.commit").create
      mappings["l"] = require("neogit.popups.log").create

      local function key_to_vim(k)
        if k == "tab" then
          return "<TAB>"
        end
        return k
      end

      local function map_to_vim(m)
        if vim.startswith(m, "control") then
          return string.format("<C-%s>", vim.split(m, " ", true)[2])
        else
          return key_to_vim(m)
        end
      end

      for k,_ in pairs(mappings) do
        vim.api.nvim_buf_set_keymap(
          buf_handle,
          "n",
          map_to_vim(k),
          string.format("<cmd>lua require('neogit.status').mappings['%s']()<CR>", k),
          {
            noremap = true,
            silent = true
          }
        )
      end
    end
  })
end

return {
  create = create,
  toggle = toggle,
  mappings = mappings
}
