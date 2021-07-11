local M = {}
local popup = require("neogit.lib.popup")
local input = require 'neogit.lib.input'
local status = require 'neogit.status'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require 'plenary.async_lib'
local await = a.await

local function push_to(popup, name, remote, branch)
  notif.create("Pushing to " .. name)
  local _, code = git.cli.push.args(unpack(popup:get_arguments())).args(remote .. " " .. branch).call_sync()
  if code == 0 then
    notif.create("Pushed to " .. name)
    await(status.refresh(true))
  end
end

local function push_upstream(popup)
  push_to(popup, "upstream", "upstream", status.repo.head.branch)
end

local function push_pushremote(popup)
  push_to(popup, "pushremote", "origin", status.repo.head.branch)
end

function M.create()
  local p = popup.builder()
    :name("NeogitPushPopup")
    :switch("f", "force-with-lease", "Force with lease")
    :switch("F", "force", "Force")
    :switch("u", "set-upstream", "Set the upstream before pushing")
    :switch("h", "no-verify", "Disable hooks")
    :switch("d", "dry-run", "Dry run")
    :action("p", "Push to pushremote", push_pushremote)
    :action("u", "Push to upstream", push_upstream)
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
