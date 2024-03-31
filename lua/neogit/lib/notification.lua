local M = {}
local config = require("neogit.config")

---@param message string  message to send
---@param level   integer vim.log.levels.X
---@param opts    table
local function create(message, level, opts)
  if opts.dismiss then
    M.delete_all()
  end

  vim.schedule(function()
    vim.notify(message, level, { title = "Neogit", icon = config.values.notification_icon })
  end)
end

---@param message string  message to send
---@param opts    table?
function M.error(message, opts)
  create(message, vim.log.levels.ERROR, opts or {})
end

---@param message string  message to send
---@param opts    table?
function M.info(message, opts)
  create(message, vim.log.levels.INFO, opts or {})
end

---@param message string  message to send
---@param opts    table?
function M.warn(message, opts)
  create(message, vim.log.levels.WARN, opts or {})
end

---@param message string  message to send
---@param opts    table?
function M.debug(message, opts)
  create(message, vim.log.levels.DEBUG, opts or {})
end

function M.delete_all()
  if type(vim.notify) == "table" and vim.notify.dismiss then
    vim.notify.dismiss()
  end
end

return M
