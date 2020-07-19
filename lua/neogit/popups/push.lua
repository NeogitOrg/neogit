local popup = require("neogit.lib.popup")
local buffer = require("neogit.buffer")
local git = require("neogit.lib.git")

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
          callback = function()
            print("Pushing to pushremote...")
            git.cli.run("push")
            print("Pushed to pushremote")
          end
        },
        {
          key = "u",
          description = "Push to upstream",
          callback = function() end
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
