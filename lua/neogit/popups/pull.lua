local popup = require("neogit.lib.popup")
local status = require 'neogit.status'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require 'plenary.async_lib'
local async, await, scheduler, void = a.async, a.await, a.scheduler, a.void

local pull_upstream = void(async(function (popup)
  local _, code = await(git.cli.pull.no_commit.args(unpack(popup.get_arguments())).call())
  if code == 0 then
    await(scheduler())
    notif.create "Pulled from upstream"
    status.refresh(true)
  end
end))

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
