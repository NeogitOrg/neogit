local cli = require("neogit.lib.git.cli")

local M = {}

function M.relpath_from_repository(path)
  local result = cli["ls-files"].others.cached.modified.deleted.full_name
    .args(path)
    .show_popup(false)
    .call { hidden = true }

  return result.stdout[1]
end

return M
