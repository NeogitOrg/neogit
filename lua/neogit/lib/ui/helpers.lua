local M = {}

---Closable must implement self:close() method
---@return function
function M.close_topmost(closable)
  return function()
    local commit_view = require("neogit.buffers.commit_view")
    local popup = require("neogit.lib.popup")
    local history = require("neogit.buffers.git_command_history")

    if popup.is_open() then
      popup.instance:close()
    elseif commit_view.is_open() then
      commit_view.instance:close()
    elseif history.is_open() then
      history.instance:close()
    else
      closable:close()
    end
  end
end

return M
