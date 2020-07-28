local popup = require("neogit.lib.popup")
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")

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
            vim.defer_fn(function()
              git.cli.run("pull", function(job)
                if job.code == 0 then
                  notif.create "Pulled from upstream"
                  __NeogitStatusRefresh()
                end
              end)
            end, 0)
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
