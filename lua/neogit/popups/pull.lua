local popup = require("neogit.lib.popup")
local status = require("neogit.status")
local input = require("neogit.lib.input")
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local pull_lib = require("neogit.lib.git.pull")
local a = require("plenary.async")

local M = {}

local function pull_from(popup, name, remote, branch)
  notif.create("Pulling from " .. name)

  local res = pull_lib.pull_interactive(remote, branch, popup:get_arguments())

  if res and res.code == 0 then
    a.util.scheduler()
    notif.create("Pulled from " .. name)
    vim.cmd("do <nomodeline> User NeogitPullComplete")
  end
  status.refresh(true, "pull_from")
end

function M.create()
  local p = popup
    .builder()
    :name("NeogitPullPopup")
    :switch("r", "rebase", "Rebase local commits", false)
    :action("p", "Pull from pushremote", function(popup)
      pull_from(popup, "pushremote", "origin", status.repo.head.branch)
    end)
    :action("u", "Pull from upstream", function(popup)
      pull_from(popup, "upstream", "upstream", status.repo.head.branch)
    end)
    :action("e", "Pull from elsewhere", function(popup)
      local remote = input.get_user_input("remote: ")
      local branch = git.branch.prompt_for_branch()
      pull_from(popup, remote, remote, branch)
    end)
    :build()

  p:show()

  return p
end

return M
