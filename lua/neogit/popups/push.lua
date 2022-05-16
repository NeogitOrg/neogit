local M = {}
local popup = require("neogit.lib.popup")
local input = require 'neogit.lib.input'
local push_lib = require 'neogit.lib.git.push'
local status = require 'neogit.status'
local notif = require("neogit.lib.notification")
local logger = require 'neogit.logger'
local git = require("neogit.lib.git")
local a = require 'plenary.async'

local function push_to(popup, name, remote, branch)
  logger.debug("Pushing to " .. name)
  notif.create("Pushing to " .. name)

  local res = push_lib.push_interactive(remote, branch, popup:to_cli())

  if res.code == 0 then
    a.util.scheduler()
    logger.error("Pushed to " .. name)
    notif.create("Pushed to " .. name)
    status.refresh(true)
    vim.cmd([[do <nomodeline> User NeogitPushComplete]])
  else
    logger.error("Failed to push to " .. name)
  end
end

function M.create()
  local p = popup.builder()
    :name("NeogitPushPopup")
    :switch("f", "force-with-lease", "Force with lease")
    :switch("F", "force", "Force")
    :switch("u", "set-upstream", "Set the upstream before pushing")
    :switch("h", "no-verify", "Disable hooks")
    :switch("d", "dry-run", "Dry run")
    :action("p", "Push to pushremote", function(popup)
      push_to(popup, "pushremote", "origin", status.repo.head.branch)
    end)
    :action("u", "Push to upstream", function(popup)
      local upstream = git.branch.get_upstream()
      a.util.scheduler()
      if upstream == nil then
        logger.error("No upstream set")
        return
      end

      push_to(popup,
        upstream.remote.." "..upstream.branch,
        upstream.remote,
        upstream.branch)
    end)
    :action("e", "Push to elsewhere", function(popup)
      local remote = input.get_user_input("remote: ")
      local branch = git.branch.prompt_for_branch(git.branch.get_all_branches())
      push_to(popup, remote, remote, branch)
    end)
    :build()

  p:show()
  
  return p
end

return M
