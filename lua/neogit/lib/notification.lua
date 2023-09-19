local M = {}

---@param message string  message to send
---@param level   integer vim.log.levels.X
local function create(message, level)
  return vim.notify(message, level, { title = "Neogit", icon = " " })
end

---@param message string  message to send
function M.error(message)
  return create(message, vim.log.levels.ERROR)
end

---@param message string  message to send
function M.info(message)
  return create(message, vim.log.levels.INFO)
end

---@param message string  message to send
function M.warn(message)
  return create(message, vim.log.levels.WARN)
end

function M.delete_all()
  if vim.notify.dismiss then
    vim.notify.dismiss()
  end
end

return M
