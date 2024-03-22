local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local git = require("neogit.lib.git")

local M = {
  values = {},
}

---Add a rev name to the mocked list of commits the user selected.
---@param rev string the rev name of the commit which the user will select once `CommitSelectViewBuffer:open_async()` is called
function M.add(rev)
  table.insert(M.values, git.rev_parse.oid(rev))
end

---Clear the table
function M.clear()
  M.values = {}
end

CommitSelectViewBuffer.open_async = function()
  return M.values
end

return M
