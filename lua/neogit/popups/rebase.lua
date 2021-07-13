local M = {}

local cli = require 'neogit.lib.git.cli'
local popup = require 'neogit.lib.popup'

function M.create()
  local p = popup.builder()
    :name("NeogitRebasePopup")
    :action("p", "Rebase onto master", function()
      cli.rebase.args("master").call_sync()
    end)
    :action("e", "Rebase onto elsewhere")
    :build()

  p:show()

  return p
end

return M
