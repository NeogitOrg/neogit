local popup = require("neogit.lib.popup")
local status = require 'neogit.status'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require('neogit.async')
local await = a.await

local function pull_upstream(popup)
  a.scope(function ()
    local _, code = await(git.cli.pull.no_commit.args(unpack(popup.get_arguments())).call())
    if code == 0 then
      await(a.scheduler())
      notif.create "Pulled from upstream"
      status.refresh(true)
    end
  end)
end

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
          callback = pull_upstream
        },
        {
          key = "u",
          description = "Pull from upstream",
          callback = pull_upstream
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
