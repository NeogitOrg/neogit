local popup = require("neogit.lib.popup")
local status = require 'neogit.status'
local input = require 'neogit.lib.input'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require 'plenary.async_lib'
local await, async, scheduler = a.await, a.async, a.scheduler

local M = {}

local pull_from = async(function(popup, name, remote, branch)
  notif.create("Pulling from " .. name)
  local _, code = await(git.cli.pull.args(unpack(popup:get_arguments())).args(remote, branch).call())
  if code == 0 then
    await(scheduler())
    notif.create("Pulled from " .. name)
    await(status.refresh(true))
  end
end)

function M.create()
  local p = popup.builder()
    :name("NeogitPullPopup")
    :switch("r", "rebase", "Rebase local commits", false)
    :action("p", "Pull from pushremote", function(popup)
      await(pull_from(popup, "pushremote", "origin", status.repo.head.branch))
    end)
    :action("u", "Pull from upstream", function(popup)
      await(pull_from(popup, "upstream", "upstream", status.repo.head.branch))
    end)
    :action("e", "Pull from elsewhere", function()
      local remote = input.get_user_input("remote: ")
      local branch = git.branch.prompt_for_branch()
      await(pull_from(popup, remote, remote, branch))
    end)
    :build()

  p:show()

  return p
end

return M
