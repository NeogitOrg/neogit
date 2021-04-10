local popup = require("neogit.lib.popup")
local status = require 'neogit.status'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require 'plenary.async_lib'
local async, await, scheduler, void = a.async, a.await, a.scheduler, a.void

local push_upstream = void(async(function (popup)
  local _, code = await(git.cli.push.args(unpack(popup.get_arguments())).call())
  if code == 0 then
    await(scheduler())
    notif.create "Pushed to pushremote"
    await(status.refresh(true))
  end
end))

local function create()
  popup.create(
    "NeogitPushPopup",
    {
      {
        key = "f",
        description = "Force with lease",
        cli = "force-with-lease",
        enabled = false
      },
      {
        key = "F",
        description = "Force",
        cli = "force",
        enabled = false
      },
      {
        key = "h",
        description = "Disable hooks",
        cli = "no-verify",
        enabled = false
      },
      {
        key = "d",
        description = "Dry run",
        cli = "dry-run",
        enabled = false
      },
    },
    {},
    {
      {
        {
          key = "p",
          description = "Push to pushremote",
          callback = push_upstream
        },
        {
          key = "u",
          description = "Push to upstream",
          callback = push_upstream
        },
        {
          key = "e",
          description = "Push to branch",
          callback = function() end
        }
      },
    })
end

return {
  create = create
}
