local M = {}

local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local actions = require("neogit.popups.bisect.actions")

function M.create(env)
  local in_progress = git.bisect.in_progress()

  local p = popup
    .builder()
    :name("NeogitBisectPopup")
    :switch("r", "no-checkout", "Don't checkout commits")
    :switch("p", "first-parent", "Follow only first parent of a merge")
    :group_heading("Bisect")
    :action("B", "Start", actions.start)
    :action("S", "Scripted", actions.scripted)
    :action_if(in_progress, "b", "Bad", actions.bad)
    :action_if(in_progress, "g", "Good", actions.good)
    :action_if(in_progress, "s", "Skip", actions.skip)
    :action_if(in_progress, "r", "Reset", actions.reset) -- call it abort?
    :action_if(in_progress, "S", "Run script", actions.run_script)
    :env(env)
    :build()

  p:show()

  return p
end

return M
