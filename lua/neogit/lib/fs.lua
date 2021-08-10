local a = require 'plenary.async_lib'
local async, await = a.async, a.await
local cli = require 'neogit.lib.git.cli'

local M = {}

M.relpath_from_repository = async(function (path)
  local result = await(cli['ls-files']
    .others
    .cached
    .modified
    .deleted
    .full_name
    .cwd('<current>')
    .args(path)
    .show_popup(false)
    .call())
  return result[1]
end)

return M
