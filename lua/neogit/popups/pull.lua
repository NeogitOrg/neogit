local popup = require("neogit.lib.popup")
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require('neogit.async')

local function create()
  popup.create(
    "NeogitPullPopup",
    {
      {
        key = "r",
        description = "Rebase local commits",
        cli = "rebase",
        enabled = false
      },
    },
    {},
    {
      {
        {
          key = "p",
          description = "Pull from pushremote",
          callback = function() end
        },
        {
          key = "u",
          description = "Pull from upstream",
          callback = function()
            a.dispatch(function ()
              local _, code = a.wait(git.cli.pull.no_commit.call())
              if code == 0 then
                a.wait_for_textlock()
                notif.create "Pulled from upstream"
                __NeogitStatusRefresh(true)
              end
            end)
          end
        },
        {
          key = "e",
          description = "Pull from elsewhere",
          callback = function() end
        },
      },
    })
end

return {
  create = create
}
