local M = {}

local dv = require 'neogit.integrations.diffview'
local config = require 'neogit.config'
local popup = require 'neogit.lib.popup'

function M.create()
  if not config.ensure_integration 'diffview' then
    return
  end

  return popup.new()
    .name("NeogitDiffPopup")
    .action("D", "diff against head", function()
      dv.open()
    end)
    .build()
end

return M
