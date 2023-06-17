local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.commit.actions")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitCommitPopup")
    :switch("a", "all", "Stage all modified and deleted files")
    :switch("e", "allow-empty", "Allow empty commit")
    :switch("v", "verbose", "Show diff of changes to be committed")
    :switch("h", "no-verify", "Disable hooks")
    :switch("s", "signoff", "Add Signed-off-by line")
    :switch("S", "no-gpg-sign", "Do not sign this commit")
    :switch("R", "reset-author", "Claim authorship and reset author date")
    :option("A", "author", "", "Override the author")
    :option("S", "gpg-sign", "", "Sign using gpg")
    :option("C", "reuse-message", "", "Reuse commit message")
    :group_heading("Create")
    :action("c", "Commit", actions.commit)
    :new_action_group("Edit HEAD")
    :action("e", "Extend", actions.extend)
    :action("w", "Reword", actions.reword)
    :action("a", "Amend", actions.amend)
    :new_action_group("Edit")
    :action("f", "Fixup", actions.fixup)
    :action("s", "Squash", actions.squash)
    :action("A", "Augment")
    :new_action_group()
    :action("F", "Instant Fixup", actions.instant_fixup)
    :action("S", "Instant Squash", actions.instant_squash)
    :env({ highlight = { "HEAD" } })
    :build()

  p:show()

  return p
end

return M
