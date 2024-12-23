local actions = require("neogit.popups.revert.actions")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}

function M.create(env)
  local in_progress = git.sequencer.pick_or_revert_in_progress()
  -- TODO: enabled = true needs to check if incompatible switch is toggled in internal state, and not apply.
  --       if you enable 'no edit', and revert, next time you load the popup both will be enabled
  --
  -- :option("s", "strategy", "", "Strategy")
  -- :switch("s", "signoff", "Add Signed-off-by lines")
  -- :option("S", "gpg-sign", "", "Sign using gpg")

  -- stylua: ignore
  local p = popup
    .builder()
    :name("NeogitRevertPopup")
    :option_if(not in_progress, "m", "mainline", "", "Replay merge relative to parent")
    :switch_if(not in_progress, "e", "edit", "Edit commit messages", { enabled = true, incompatible = { "no-edit" } })
    :switch_if(not in_progress, "E", "no-edit", "Don't edit commit messages", { incompatible = { "edit" } })
    :group_heading("Revert")
    :action_if(not in_progress, "v", "Commit(s)", actions.commits)
    :action_if(not in_progress, "V", "Changes", actions.changes)
    :action_if(in_progress, "v", "continue", actions.continue)
    :action_if(in_progress, "s", "skip", actions.skip)
    :action_if(in_progress, "a", "abort", actions.abort)
    :env(env)
    :build()

  p:show()

  return p
end

return M
