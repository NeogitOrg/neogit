local M = {}

local cli = require 'neogit.lib.git.cli'
local popup = require 'neogit.lib.popup'

function M.create()
  return popup.new()
    .name("NeogitRebasePopup")
    .action("p", "Rebase onto master", function()
      cli.rebase.args("master").call_sync()
    end)
    .action("e", "Rebase onto elsewhere")
    .build()
end

return M
