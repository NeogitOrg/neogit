local M = {}

local config = require 'neogit.config'
local popup = require 'neogit.lib.popup'

function M.create()
  if not config.ensure_integration 'diffview' then
    return
  end

  return popup.new()
    .name("NeogitDiffPopup")
    .action("D", "diff against head", function()
      require 'neogit.integrations.diffview'.open()
    end)
    .build()
end

return M
