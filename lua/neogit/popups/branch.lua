local status = require 'neogit.status'
local popup = require('neogit.lib.popup')
local branch = require('neogit.lib.git.branch')
local operation = require('neogit.operations')
local a = require 'plenary.async_lib'
local async, await = a.async, a.await

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
        callback = operation('checkout_branch', async(function ()
          await(branch.checkout())
          status.refresh(true)
        end))
      },
      {
        key = "l",
        description = "checkout local branch",
        callback = operation('checkout_local-branch', async(function ()
          await(branch.checkout_local())
          status.refresh(true)
        end))
      }
    },
    {
      {
        key = "c",
        description = "checkout new branch",
        callback = operation('checkout_create-branch', async(function ()
          await(branch.checkout_new())
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
