local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")

local api = vim.api

---@class LocationInHunk
---@field old integer
---@field new integer
---@field line string
local M = {}

---@param start_line integer
---@param offset integer
---@param lines string[]
---@param adjust_on string
---@return integer
function M.adjust_row(start_line, offset, lines, adjust_on)
  local row = start_line + offset - 1

  for i = 1, offset do
    if string.sub(lines[i], 1, 1) == adjust_on then
      row = row - 1
    end
  end

  return math.max(row, 1)
end

---@param hunk Hunk
---@param offset integer 1-based offset inside `hunk.lines`
---@return LocationInHunk|nil
function M.translate_hunk_location(hunk, offset)
  if not hunk or not hunk.lines then
    return
  end

  if offset < 1 or offset > #hunk.lines then
    return
  end

  return {
    old = M.adjust_row(hunk.disk_from, offset, hunk.lines, "+"),
    new = M.adjust_row(hunk.index_from, offset, hunk.lines, "-"),
    line = hunk.lines[offset] or "",
  }
end

---@param command string vim command such as "edit" or "split"
---@param path string absolute file path to open
---@param cursor? integer[] cursor location in the target buffer
---@param cmd_debug_prefix? string If given, executed commands will be logged prefixed with this tag
function M.open(command, path, cursor, cmd_debug_prefix)
  local logger = require("neogit.logger")
  local line = cursor and cursor[1] or "1"
  local cmd = ("silent! %s %s | %s"):format(command, vim.fn.fnameescape(path), line)
  if cmd_debug_prefix ~= nil then
    logger.debug(cmd_debug_prefix .. " '" .. cmd .. "'")
  end
  vim.cmd(cmd)
  cmd = "redraw! | norm! zz"
  if cmd_debug_prefix ~= nil then
    logger.debug(cmd_debug_prefix .. " '" .. cmd .. "'")
  end
  vim.cmd(cmd)
end

---@param win integer
---@return boolean
local function window_belongs_to_user(win)
  if not api.nvim_win_is_valid(win) then
    return false
  end

  local cfg = api.nvim_win_get_config(win)
  if cfg.relative and cfg.relative ~= "" then
    return false
  end

  local buf = api.nvim_win_get_buf(win)
  if buf == 0 or not api.nvim_buf_is_valid(buf) then
    return false
  end

  if vim.fn.buflisted(buf) ~= 1 then
    return false
  end

  local buftype = api.nvim_get_option_value("buftype", { buf = buf })
  if buftype ~= "" then
    return false
  end

  local filetype = api.nvim_get_option_value("filetype", { buf = buf }) or ""
  return not vim.startswith(filetype, "Neogit")
end

---@return table Ordered list of tabs to check for user windows
local function ordered_tabpages()
  local current_tab = api.nvim_get_current_tabpage()
  local tabs = api.nvim_list_tabpages()
  local added = { [current_tab] = true }
  local order = { current_tab }

  local previous_number = vim.fn.tabpagenr("#")
  if previous_number > 0 then
    for _, tab in ipairs(tabs) do
      if not added[tab] and api.nvim_tabpage_get_number(tab) == previous_number then
        table.insert(order, tab)
        added[tab] = true
        break
      end
    end
  end

  for _, tab in ipairs(tabs) do
    if not added[tab] then
      table.insert(order, tab)
      added[tab] = true
    end
  end

  return order
end

---@return integer? A window handle that doesn't belong to Neogit
local function find_user_window()
  for _, tab in ipairs(ordered_tabpages()) do
    for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
      if window_belongs_to_user(win) then
        return win
      end
    end
  end
end

---@return boolean true if the focus succeeded
local function focus_user_window()
  local user_window = find_user_window()
  if not user_window then
    return false
  end
  local target_tab = api.nvim_win_get_tabpage(user_window)
  if target_tab ~= api.nvim_get_current_tabpage() then
    pcall(api.nvim_set_current_tabpage, target_tab)
  end
  if user_window ~= api.nvim_get_current_win() then
    pcall(api.nvim_set_current_win, user_window)
  end
  return true
end

---@param path string
---@param cursor integer[]
function M.goto_file_at(path, cursor)
  local absolute_path = vim.fs.joinpath(git.repo.worktree_root, path)

  local path_exists = require("plenary.path"):new(path):exists()
  if not path_exists then
    notification.warn("Path " .. path .. " not found in current HEAD")
    return
  end

  vim.schedule(function()
    if not focus_user_window() then
      vim.cmd("tabnew")
    end
    M.open("edit", absolute_path, cursor, "[CommitView - Open]")
  end)
end

---Opens a virtual buffer with the given lines in a new tab and places the cursor at the given location
---path and rev are used to set the buffer name
---@param bufname string
---@param filetype? string
---@param cursor integer[]
---@param lines string[]
---@param after_delbuf_cb fun()
local function open_lines_in_virtual_file_in_tab(bufname, filetype, cursor, lines, after_delbuf_cb)
  local win = api.nvim_get_current_win()
  local buf = api.nvim_create_buf(false, true)

  api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  api.nvim_set_option_value("swapfile", false, { buf = buf })
  api.nvim_set_option_value("modifiable", true, { buf = buf })

  api.nvim_buf_set_name(buf, bufname)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  if filetype then
    vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
  end

  api.nvim_set_option_value("modifiable", false, { buf = buf })
  api.nvim_set_option_value("readonly", true, { buf = buf })

  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", function()
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_delete(buf, { force = true })
    end

    after_delbuf_cb()

    local new_win = api.nvim_get_current_win()
    if api.nvim_win_is_valid(win) and win ~= new_win then
      api.nvim_win_close(win, true)
    end
  end, opts)

  api.nvim_win_set_buf(win, buf)
  if cursor then
    pcall(api.nvim_win_set_cursor, win, { math.max(cursor[1], 1), cursor[2] or 0 })
  end

  vim.cmd("normal! zz")
end

---@param target_commit string
---@param path string
---@param cursor integer[]
---@param reopen_cb fun()
function M.goto_file_in_commit_at(target_commit, path, cursor, reopen_cb)
  local file_contents =
    git.cli.show.file(path, target_commit).call { hidden = true, trim = false, ignore_error = true }
  if not file_contents or file_contents.code ~= 0 then
    notification.error(("Unable to read %s at %s"):format(path, target_commit))
    return
  end

  local lines = file_contents.stdout
  if #lines == 0 then
    lines = { "" }
  end

  local bufname = ("neogit://%s/%s"):format(target_commit, path)
  local filetype = vim.filetype.match { filename = path }
  open_lines_in_virtual_file_in_tab(bufname, filetype, cursor, lines, reopen_cb)
end

return M
