local M = {}

local config = require 'neogit.config'
local popup = require 'neogit.lib.popup'

function M.create()
  if not config.ensure_integration 'diffview' then
    return
  end

  return popup.new()
    .build()
end

return M
