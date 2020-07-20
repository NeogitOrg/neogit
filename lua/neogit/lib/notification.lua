local util = require("neogit.lib.util")
local message_history = {}
local notifications = {}
local notification_count = 0

vim.api.nvim_command("hi NeogitNotificationInfo guifg=#80ff95")
vim.api.nvim_command("hi NeogitNotificationWarning guifg=#fff454")
vim.api.nvim_command("hi NeogitNotificationError guifg=#c44323")

local function create(message, options)
  notification_count = notification_count + 1

  if type(message) == "string" then
    message = { message }
  end

  if type(message) ~= "table" then
    error("First argument has to be either a table or a string")
  end

  options = options or {
    type = "info"
  }
  local prev_notification = notifications[notification_count - 1] or {height = 0, row = vim.api.nvim_get_option("lines") - 2}
  local width = util.tbl_longest_str(message)
  local height = #message
  local padding = 2 + prev_notification.height
  local row = prev_notification.row - padding
  local col = vim.api.nvim_get_option("columns") - 3

  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, message)

  local window = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    anchor = "SE",
    height = height,
    style = "minimal"
  })

  local border_buf = vim.api.nvim_create_buf(false, true)
  local border_buf_lines = {}
  width = width + 2

  table.insert(border_buf_lines, string.format("╭%s╮", string.rep("─", width)))

  for i=1,height do
    table.insert(border_buf_lines, string.format("│%s│", string.rep(" ", width)))
  end

  table.insert(border_buf_lines, string.format("╰%s╯", string.rep("─", width)))

  vim.api.nvim_buf_set_lines(border_buf, 0, -1, false, border_buf_lines)

  local border_win = vim.api.nvim_open_win(border_buf, false, {
    relative = "editor",
    row = row + 1,
    col = col + 3,
    width = width + 3,
    anchor = "SE",
    height = height + 2,
    style = "minimal"
  })

  if options.type == "info" then
    vim.api.nvim_win_set_option(window, "winhl", "Normal:NeogitNotificationInfo")
    vim.api.nvim_win_set_option(border_win, "winhl", "Normal:NeogitNotificationInfo")
  elseif options.type == "warning" then
    vim.api.nvim_win_set_option(window, "winhl", "Normal:NeogitNotificationWarning")
    vim.api.nvim_win_set_option(border_win, "winhl", "Normal:NeogitNotificationWarning")
  else
    vim.api.nvim_win_set_option(window, "winhl", "Normal:NeogitNotificationError")
    vim.api.nvim_win_set_option(border_win, "winhl", "Normal:NeogitNotificationError")
  end

  table.insert(notifications, {
    window = window,
    buffer = buffer,
    height = height,
    width = width,
    row = row,
    col = col,
    border = {
      window = border_win,
      buffer = border_buf
    },
    content = message
  })

  local timer

  local function delete()
    notification_count = notification_count - 1

    if timer:is_active() then
      timer:stop()
    end

    for i, n in pairs(notifications) do
      if n.window == window then
        if notifications[i] == nil then
          return
        end
        notifications[i] = nil
        break
      end
    end

    table.insert(message_history, {
      content = message,
      type = options.type
    })

    if vim.api.winbufnr(window) ~= -1 then
      vim.api.nvim_win_close(window, false)
      vim.api.nvim_win_close(border_win, false)
    end
  end

  timer = vim.defer_fn(delete, options.delay or 2000)

  return delete
end

return {
  create = create,
  get_history = function() return message_history end
}
