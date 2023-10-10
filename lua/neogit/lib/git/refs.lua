local cli = require("neogit.lib.git.cli")

local M = {}

--- Lists revisions
---@return table
function M.list()
  local revisions = cli["for-each-ref"].format('"%(refname:short)"').call():trim().stdout
  for i, str in ipairs(revisions) do
    revisions[i] = string.sub(str, 2, -2)
  end
  return revisions
end

return M
