local M = {}

local config = require("neogit.config")
local popup = require("neogit.lib.popup")
local notification = require("neogit.lib.notification")

function M.create()
  if not config.check_integration("diffview") then
    notification.error("Diffview integration must be enabled for diff popup")
    return
  end

  local p = popup
    .builder()
    :name("NeogitDiffPopup")
    :action("D", "diff against head", function()
      require("neogit.integrations.diffview").open()
    end)
    :build()

  p:show()

  return p
end

return M
