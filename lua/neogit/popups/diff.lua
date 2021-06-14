local M = {}

local config = require 'neogit.config'
local popup = require 'neogit.lib.popup'

function M.create()
  if not config.ensure_integration 'diffview' then
    return
  end

  local p = popup.builder()
    :name("NeogitDiffPopup")
    :action("D", "diff against head", function()
      require 'neogit.integrations.diffview'.open()
    end)
    :build()

  p:show()

  return p
end

return M
