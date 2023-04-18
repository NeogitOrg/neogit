local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local a = require("plenary.async")
local notif = require("neogit.lib.notification")
local fetch_lib = require("neogit.lib.git.fetch")
local input = require("neogit.lib.input")
local status = require("neogit.status")

local M = {}

local function fetch_from(name, remote, branch, args)
  notif.create("Fetching from " .. name)
  local res = fetch_lib.fetch_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    notif.create("Fetched from " .. name)
    vim.cmd("do <nomodeline> User NeogitFetchComplete")
  end
end

function M.create()
  local p = popup
    .builder()
    :name("NeogitFetchPopup")
    :switch("p", "prune", "Prune deleted branches")
    :switch("t", "tags", "Fetch all tags")
    :group_heading("Fetch from")
    :action("p", "pushRemote", function(popup)
      fetch_from("pushremote", "origin", status.repo.head.branch, popup:get_arguments())
    end)
    :action("u", "upstream", function(popup)
      local upstream = git.branch.get_upstream()
      if not upstream then
        return
      end

      fetch_from(upstream.remote, upstream.remote, "", popup:get_arguments())
    end)
    :action("a", "all remotes", function(popup)
      fetch_from("all remotes", "", "", { unpack(popup:get_arguments()), "--all" })
    end)
    :action("e", "elsewhere", function(popup)
      local remote = input.get_user_input("remote: ")
      local branch = git.branch.prompt_for_branch()
      fetch_from(remote .. " " .. branch, remote, branch, popup:get_arguments())
    end)
    :new_action_group("Fetch")
    :action("o", "another branch", false)
    :action("r", "explicit refspec", false)
    :action("m", "submodules", false)
    :new_action_group("Configure")
    :action("C", "Set variables...", function()
      require("neogit.popups.branch_config").create()
    end)
    :build()

  p:show()

  return p
end

return M
