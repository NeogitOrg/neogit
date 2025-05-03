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
    :action("x", "Absorb", actions.absorb)
    :new_action_group("Edit HEAD")
    :action("e", "Extend", actions.extend)
    :action("w", "Reword", actions.reword)
    :action("a", "Amend", actions.amend)
    :new_action_group("Edit")
    :action("f", "Fixup", actions.fixup)
    :action("s", "Squash", actions.squash)
    :action("A", "Augment", actions.augment)
    :new_action_group()
    :action("F", "Instant Fixup", actions.instant_fixup)
    :action("S", "Instant Squash", actions.instant_squash)
    :env({ highlight = { "HEAD" }, commit = env.commit })
    :build()

  p:show()

  return p
end

return M
