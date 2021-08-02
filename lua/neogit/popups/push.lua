local M = {}
local popup = require("neogit.lib.popup")
local input = require 'neogit.lib.input'
local push_lib = require 'neogit.lib.git.push'
local status = require 'neogit.status'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require 'plenary.async_lib'
local await, async, scheduler = a.await, a.async, a.scheduler

local push_to = async(function(_popup, name, remote, branch)
  notif.create("Pushing to " .. name)

  local res = await(push_lib.push_interactive(remote, branch))

  if res.code == 0 then
    await(scheduler())
    notif.create("Pushed to " .. name)
    await(status.refresh(true))
  end
end)

function M.create()
  local p = popup.builder()
    :name("NeogitPushPopup")
    :switch("f", "force-with-lease", "Force with lease")
    :switch("F", "force", "Force")
    :switch("u", "set-upstream", "Set the upstream before pushing")
    :switch("h", "no-verify", "Disable hooks")
    :switch("d", "dry-run", "Dry run")
    :action("p", "Push to pushremote", function(popup)
      await(push_to(popup, "pushremote", "origin", status.repo.head.branch))
    end)
    :action("u", "Push to upstream", function(popup)
      await(push_to(popup, "upstream", "upstream", status.repo.head.branch))
    end)
    :action("e", "Push to elsewhere", function()
      local remote = input.get_user_input("remote: ")
      local branch = git.branch.prompt_for_branch()
      push_to(popup, remote, remote, branch)
    end)
    :build()

  p:show()
  
  return p
end

return M
