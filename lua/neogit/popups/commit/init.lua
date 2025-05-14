local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.commit.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeogitCommitPopup")
    :switch("a", "all", "Stage all modified and deleted files")
    :switch("e", "allow-empty", "Allow empty commit", { persisted = false })
    :switch("v", "verbose", "Show diff of changes to be committed")
    :switch("h", "no-verify", "Disable hooks")
    :switch("R", "reset-author", "Claim authorship and reset author date")
    :option("A", "author", "", "Override the author", { key_prefix = "-" })
    :switch("s", "signoff", "Add Signed-off-by line")
    :option("S", "gpg-sign", "", "Sign using gpg", { key_prefix = "-" })
    :option("C", "reuse-message", "", "Reuse commit message", { key_prefix = "-" })
    :group_heading("Create")
    :action("c", "Commit", actions.commit)
    :new_action_group("Edit HEAD")
    :action("e", "Extend", actions.extend)
    :spacer()
    :action("a", "Amend", actions.amend)
    :spacer()
    :action("w", "Reword", actions.reword)
    :new_action_group("Edit")
    :action("f", "Fixup", actions.fixup)
    :action("s", "Squash", actions.squash)
    :action("A", "Alter", actions.alter)
    :action("n", "Augment", actions.augment)
    :action("W", "Revise", actions.revise)
    :new_action_group("Edit and rebase")
    :action("F", "Instant Fixup", actions.instant_fixup)
    :action("S", "Instant Squash", actions.instant_squash)
    :new_action_group("Spread across commits")
    :action("x", "Absorb", actions.absorb)
    :env({ highlight = { "HEAD" }, commit = env.commit })
    :build()

  p:show()

  return p
end

return M
