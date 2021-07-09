local popup = require("neogit.lib.popup")
local status = require 'neogit.status'
local input = require 'neogit.lib.input'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require 'plenary.async_lib'
local await = a.await

local M = {}

local function pull_from(popup, name, remote, branch)
  notif.create("Pulling from " .. name)
  local _, code = git.cli.pull.args(unpack(popup:get_arguments())).args(remote .. " " .. branch).call_sync()
  if code == 0 then
    notif.create("Pulled from " .. name)
    await(status.refresh(true))
  end
end

local function pull_upstream(popup)
  pull_from(popup, "upstream", "upstream", status.repo.head.branch)
end

local function pull_pushremote(popup)
  pull_from(popup, "pushremote", "origin", status.repo.head.branch)
end

function M.create()
  local p = popup.builder()
    :name("NeogitPullPopup")
    :switch("r", "rebase", "Rebase local commits", false)
    :action("p", "Pull from pushremote", pull_pushremote)
    :action("u", "Pull from upstream", pull_upstream)
    :action("e", "Pull from elsewhere", function()
      local remote = input.get_user_input("remote: ")
      local branch = git.branch.prompt_for_branch()
      pull_from(popup, remote, remote, branch)
    end)
    :build()

  p:show()

  return p
end

return M
