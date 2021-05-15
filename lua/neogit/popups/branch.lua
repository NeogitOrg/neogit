local M = {}
local status = require 'neogit.status'
local popup = require('neogit.lib.popup')
local branch = require('neogit.lib.git.branch')
local operation = require('neogit.operations')
local a = require 'plenary.async_lib'
local async, await = a.async, a.await

function M.create()
  return popup.new()
    .name('NeogitBranchPopup')
    .action("b", "checkout branch/revision", operation('checkout_branch', async(function ()
      await(branch.checkout())
      await(status.refresh(true))
    end)))
    .action("l", "checkout local branch", operation('checkout_local-branch', async(function ()
      await(branch.checkout_local())
      await(status.refresh(true))
    end)))
    .action("c", "checkout new branch", operation('checkout_create-branch', async(function ()
      await(branch.checkout_new())
      await(status.refresh(true))
    end)))
    .build()
end

return M
