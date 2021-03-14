local popup = require("neogit.lib.popup")
local GitCommandHistory = require("neogit.buffers.git_command_history")
local Buffer = require("neogit.lib.buffer")
local git = require("neogit.lib.git")
local a = require('neogit.async')

local function create()
  popup.create(
    "NeogitHelpPopup",
    {},
    {},
    {
      {
        {
          key = "p",
          description = "Pull",
          callback = function(popup)
            require('neogit.popups.pull').create()
          end
        },
      },
      {
        {
          key = "P",
          description = "Push",
          callback = function(popup)
            require('neogit.popups.push').create()
            popups.push.create()
          end
        },
      },
      {
        {
          key = "Z",
          description = "Stash",
          callback = function(popup)
            require('neogit.popups.stash').create()
            popups.stash.create(vim.fn.getpos('.'))
          end
        },
      },
      {
        {
          key = "L",
          description = "Log",
          callback = function(popup)
            require('neogit.popups.log').create()
            popups.log.create()
          end
        },
      },
      {
        {
          key = "c",
          description = "Commit",
          callback = function(popup)
            require('neogit.popups.commit').create()
          end
        },
      },
      {
        {
          key = "$",
          description = "Git Command History",
          callback = function(popup)
            GitCommandHistory:new():show()
          end
        },
      },
      {
        {
          key = "<c-r>",
          description = "Refresh Status Buffer",
          callback = function(popup)
            __NeogitStatusRefresh(true)
          end
        },
      },
    })
end

return {
  create = create
}
