local M = {}

---@param message string  message to send
---@param level   integer vim.log.levels.X
---@param opts    table
local function create(message, level, opts)
  if opts.dismiss then
    M.delete_all()
  end

  return vim.notify(message, level, { title = "Neogit", icon = " " })
end

---@param message string  message to send
---@param opts    table?
function M.error(message, opts)
  return create(message, vim.log.levels.ERROR, opts or {})
end

---@param message string  message to send
---@param opts    table?
function M.info(message, opts)
  return create(message, vim.log.levels.INFO, opts or {})
end

---@param message string  message to send
---@param opts    table?
function M.warn(message, opts)
  return create(message, vim.log.levels.WARN, opts or {})
end

function M.delete_all()
  if vim.notify.dismiss then
    vim.notify.dismiss()
  end
end

return M
