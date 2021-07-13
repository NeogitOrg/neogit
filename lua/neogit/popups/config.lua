local M = {}

local config = require 'neogit.config'
local popup = require 'neogit.lib.popup'

function M.create()
  local p = popup.builder()
    :name("NeogitConfigPopup")
    :build()

  p:show()

  return p
end

return M
