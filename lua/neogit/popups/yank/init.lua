local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.yank.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeogitYankPopup")
    :group_heading("Yank Commit info")
    :action("Y", "Hash", actions.hash)
    :action("s", "Subject", actions.subject)
    :action("m", "Message (subject and body)", actions.message)
    :action("b", "Message body", actions.body)
    :action_if(env.url, "u", "URL", actions.url)
    :action("d", "Diff", actions.diff)
    :action("a", "Author", actions.author)
    :action_if(env.tags ~= "", "t", "Tags", actions.tags)
    :env(env)
    :build()

  p:show()

  return p
end

return M
