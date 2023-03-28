-- https://magit.vc/manual/2.11.0/magit/Remotes.html#Remotes
--
local popup = require("neogit.lib.popup")
local input = require("neogit.lib.input")
local git = require("neogit.lib.git")

local M = {}

function M.create()
  local p = popup.builder()
    :name("NeogitRemotePopup")
    :switch("f", "f", "Fetch after add", true)
    :config("u", "remote.origin.url")
    :config("U", "remote.origin.fetch")
    :config("s", "remote.origin.pushurl")
    :config("S", "remote.origin.push")
    :config("O", "remote.origin.tagOpt", { "", "--no-tags", "--tags" })
    :group_heading("Actions")
    :action("a", "Add", function()
      local name = input.get_user_input("Remote name: ")
      -- TODO: Github isn't the default - use existing remote as template
      local remote_url = input.get_user_input(
        "Remote url: ",
        "git@github.com:" .. name .. "/" .. git.branch.current() .. ".git"
      )

      local result = git.remote.add(name, remote_url)
      if result.code ~= 0 then
        return
      end

      local set_default = input.get_confirmation(
        [[Set 'remote.pushDefault' to "]] .. name .. [["?]],
        { values = { "&Yes", "&No" }, default = 2 }
      )

      if set_default then
        git.config.set("remote.pushDefault", name)
      end
    end)
    :action("r", "Rename", false)
    :action("x", "Remove", false)
    :new_action_group()
    :action("C", "Configure...", false)
    :action("p", "Prune stale branches", false)
    :action("P", "Prune stale refspecs", false)
    :action("b", "Update default branch", false)
    :build()

  p:show()

  return p
end

return M
