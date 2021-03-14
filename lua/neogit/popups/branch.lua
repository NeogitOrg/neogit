local a = require('neogit.async')
local popup = require('neogit.lib.popup')
local branch = require('neogit.lib.git.branch')
local operation = require('neogit.operations')

local configuration = {
  {

  },
  {

  },
  {
    {
      {
        key = "b",
        description = "checkout branch/revision",
        callback = operation('checkout_branch', a.sync(function ()
          a.wait(branch.checkout())
          __NeogitStatusRefresh(true)
        end))
      },
      {
        key = "l",
        description = "checkout local branch",
        callback = operation('checkout_local-branch', a.sync(function ()
          a.wait(branch.checkout_local())
          __NeogitStatusRefresh(true)
        end))
      }
    },
    {
      {
        key = "c",
        description = "checkout new branch",
        callback = operation('checkout_create-branch', a.sync(function ()
          a.wait(branch.checkout_new())
          __NeogitStatusRefresh(true)
        end))
      }
    }
  }
}

local function create()
  popup.create('NeogitBranchPopup', unpack(configuration))
end

return {
  create = create
}
