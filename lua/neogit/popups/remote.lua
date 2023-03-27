-- https://magit.vc/manual/2.11.0/magit/Remotes.html#Remotes
--
local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local status = require("neogit.status")

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
    :action("a", "Add", false)
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
