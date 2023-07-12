local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.merge.actions")

local M = {}

function M.create()
  local in_merge = actions.in_merge()
  local p = popup
    .builder()
    :name("NeogitMergePopup")
    :group_heading_if(in_merge, "Actions")
    :action_if(in_merge, "m", "Commit merge", actions.commit)
    :action_if(in_merge, "a", "Abort merge", actions.abort)
    :switch_if(not in_merge, "f", "ff-only", "Fast-forward only", { incompatible = { "no-ff" } })
    :switch_if(not in_merge, "n", "no-ff", "No fast-forward", { incompatible = { "ff-only" } })
    :switch_if(
      not in_merge,
      "b",
      "Xignore-space-change",
      "Ignore changes in amount of whitespace",
      { cli_prefix = "-" }
    )
    :switch_if(
      not in_merge,
      "w",
      "Xignore-all-space",
      "Ignore whitespace when comparing lines",
      { cli_prefix = "-" }
    )
    :option_if(not in_merge, "s", "strategy", "", "Strategy", {
      choices = { "resolve", "recursive", "octopus", "ours", "subtree" },
    })
    :option_if(not in_merge, "X", "strategy-option", "", "Strategy Option", {
      choices = { "ours", "theirs", "patience" },
    })
    :option_if(not in_merge, "A", "Xdiff-algorithm", "", "Diff algorithm", {
      cli_prefix = "-",
      choices = { "default", "minimal", "patience", "histogram" },
    })
    :option_if(not in_merge, "S", "gpg-sign", "", "Sign using gpg")
    :group_heading_if(not in_merge, "Actions")
    :action_if(not in_merge, "m", "Merge", actions.merge)
    :action_if(not in_merge, "e", "Merge and edit message") -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L105
    :action_if(not in_merge, "n", "Merge but don't commit") -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L119
    :action_if(not in_merge, "A", "Absorb") -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L158
    :new_action_group_if(not in_merge, "")
    :action_if(not in_merge, "p", "Preview merge") -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L225
    :action_if(not in_merge, "s", "Squash merge") -- -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L217
    :group_heading_if(not in_merge, "")
    :action_if(not in_merge, "i", "Dissolve") -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L131
    :build()

  p:show()

  return p
end

return M
