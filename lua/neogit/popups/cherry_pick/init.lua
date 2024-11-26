local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.cherry_pick.actions")
local git = require("neogit.lib.git")

local M = {}

function M.create(env)
  local in_progress = git.sequencer.pick_or_revert_in_progress()

  local p = popup
    .builder()
    :name("NeogitCherryPickPopup")
    :option_if(not in_progress, "m", "mainline", "", "Replay merge relative to parent", {
      key_prefix = "-",
    })
    :option_if(not in_progress, "s", "strategy", "", "Strategy", {
      key_prefix = "=",
      choices = { "octopus", "ours", "resolve", "subtree", "recursive" },
    })
    :switch_if(not in_progress, "F", "ff", "Attempt fast-forward", {
      enabled = true,
      incompatible = { "edit" },
    })
    :switch_if(not in_progress, "x", "x", "Reference cherry in commit message", {
      cli_prefix = "-",
    })
    :switch_if(not in_progress, "e", "edit", "Edit commit messages", {
      incompatible = { "ff" },
    })
    :switch_if(not in_progress, "s", "signoff", "Add Signed-off-by lines")
    :option_if(not in_progress, "S", "gpg-sign", "", "Sign using gpg", {
      key_prefix = "-",
    })
    :group_heading_if(not in_progress, "Apply here")
    :action_if(not in_progress, "A", "Pick", actions.pick)
    :action_if(not in_progress, "a", "Apply", actions.apply)
    :action_if(not in_progress, "h", "Harvest", actions.harvest)
    :action_if(not in_progress, "m", "Squash", actions.squash)
    :new_action_group_if(not in_progress, "Apply elsewhere")
    :action_if(not in_progress, "d", "Donate", actions.donate)
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
