local notification = require("neogit.lib.notification")
local M = {}

---@param key string
---@return fun(popup: PopupData)
local function yank(key)
  return function(popup)
    local data = popup:get_env(key)
    if data then
      vim.fn.setreg("+", data)
      notification.info(("Copied %s to clipboard."):format(key))
    end
  end
end

M.hash = yank("hash")
M.subject = yank("subject")
M.message = yank("message")
M.body = yank("body")
M.url = yank("url")
M.diff = yank("diff")
M.author = yank("author")
M.tags = yank("tags")

return M
