local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.cherry_pick.actions")

local M = {}

function M.create(env)
  local in_progress = require("neogit.lib.git.sequencer").pick_or_revert_in_progress()

  -- TODO
  -- :switch("x", "x", "Reference cherry in commit message", { cli_prefix = "-" })
  -- :switch("e", "edit", "Edit commit messages", false)
  -- :switch("s", "signoff", "Add Signed-off-by lines", false)
  -- :option("m", "mainline", "", "Replay merge relative to parent")
  -- :option("s", "strategy", "", "Strategy")
  -- :option("S", "gpg-sign", "", "Sign using gpg")

  local p = popup
    .builder()
    :name("NeogitCherryPickPopup")
    :switch_if(not in_progress, "F", "ff", "Attempt fast-forward", { enabled = true })
    :group_heading_if(not in_progress, "Apply here")
    :action_if(not in_progress, "A", "Pick", actions.pick)
    :action_if(not in_progress, "a", "Apply", actions.apply)
    :action_if(not in_progress, "h", "Harvest")
    :action_if(not in_progress, "m", "Squash")
    :new_action_group_if(not in_progress, "Apply elsewhere")
    :action_if(not in_progress, "d", "Donate")
    :action_if(not in_progress, "n", "Spinout")
    :action_if(not in_progress, "s", "Spinoff")
    :group_heading_if(in_progress, "Cherry Pick")
    :action_if(in_progress, "A", "continue", actions.continue)
    :action_if(in_progress, "s", "skip", actions.skip)
    :action_if(in_progress, "a", "abort", actions.abort)
    :env(env)
    :build()

  p:show()

  return p
end

return M
