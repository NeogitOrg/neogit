local M = {}
local status = require 'neogit.status'
local cli = require 'neogit.lib.git.cli'
local popup = require('neogit.lib.popup')
local branch = require('neogit.lib.git.branch')
local operation = require('neogit.operations')

function M.create()
  local p = popup.builder()
    :name('NeogitBranchPopup')
    :action("n", "create branch", operation('create_branch', function ()
      branch.create()
      status.refresh(true)
    end))
    :action("b", "checkout branch/revision", operation('checkout_branch', function ()
      branch.checkout()
      status.refresh(true)
    end))
    :action("d", "delete local branch", operation('delete_branch', function ()
      branch.delete()
      status.refresh(true)
    end))
    :action("D", "delete local branch and remote", operation('delete_branch', function ()
      local branch = branch.delete()
      if branch and branch ~= '' then
        cli.interactive_git_cmd(tostring(cli.push.remote("origin").delete.to(branch)))
      end
      status.refresh(true)
    end))
    :action("l", "checkout local branch", operation('checkout_local-branch', function ()
      branch.checkout_local()
      status.refresh(true)
    end))
    :action("c", "checkout new branch", operation('checkout_create-branch', function ()
      branch.checkout_new()
      status.refresh(true)
    end))
    :build()

  p:show()

  return p
end

return M
