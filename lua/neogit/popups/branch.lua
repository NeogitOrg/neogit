local a = require('neogit.async')
local status = require 'neogit.status'
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
          status.refresh(true)
        end))
      },
      {
        key = "l",
        description = "checkout local branch",
        callback = operation('checkout_local-branch', a.sync(function ()
          a.wait(branch.checkout_local())
          status.refresh(true)
        end))
      }
    },
    {
      {
        key = "c",
        description = "checkout new branch",
        callback = operation('checkout_create-branch', a.sync(function ()
          a.wait(branch.checkout_new())
          status.refresh(true)
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
