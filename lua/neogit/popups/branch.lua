local M = {}
local status = require 'neogit.status'
local cli = require 'neogit.lib.git.cli'
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
    .action("d", "delete local branch", operation('delete_branch', async(function ()
      await(branch.delete())
      await(status.refresh(true))
    end)))
    .action("D", "delete local branch and remote", operation('delete_branch', async(function ()
      local branch = await(branch.delete())
      await(cli.push.delete.to("origin " .. branch).call())
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
