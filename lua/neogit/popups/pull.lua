local popup = require("neogit.lib.popup")
local status = require 'neogit.status'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require 'plenary.async_lib'
local async, await, scheduler, void = a.async, a.await, a.scheduler, a.void

local M = {}

local pull_upstream = void(async(function (popup)
  local _, code = await(git.cli.pull.no_commit.args(unpack(popup:get_arguments())).call())
  if code == 0 then
    await(scheduler())
    notif.create "Pulled from upstream"
    await(status.refresh(true))
  end
end))

function M.create()
  local p = popup.builder()
    :name("NeogitPullPopup")
    :switch("r", "rebase", "Rebase local commits", false)
    :action("p", "Pull from pushremote", pull_upstream)
    :action("u", "Pull from upstream", pull_upstream)
    :action("e", "Pull from elsewhere")
    :build()

  p:show()

  return p
end

return M
