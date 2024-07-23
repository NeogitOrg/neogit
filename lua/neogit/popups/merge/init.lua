local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.merge.actions")
local git = require("neogit.lib.git")

local M = {}

function M.create(env)
  local in_merge = git.merge.in_progress()
  local p = popup
    .builder()
    :name("NeogitMergePopup")
    :group_heading_if(in_merge, "Actions")
    :action_if(in_merge, "m", "Commit merge", actions.commit)
    :action_if(in_merge, "a", "Abort merge", actions.abort)
    :switch_if(not in_merge, "f", "ff-only", "Fast-forward only", { incompatible = { "no-ff" } })
    :switch_if(not in_merge, "n", "no-ff", "No fast-forward", { incompatible = { "ff-only" } })
    :option_if(not in_merge, "s", "strategy", "", "Strategy", {
      choices = { "octopus", "ours", "resolve", "subtree", "recursive" },
      key_prefix = "-",
    })
    :option_if(not in_merge, "X", "strategy-option", "", "Strategy Option", {
      choices = { "ours", "theirs", "patience" },
      key_prefix = "-",
    })
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
    :option_if(not in_merge, "A", "Xdiff-algorithm", "", "Diff algorithm", {
      choices = { "default", "minimal", "patience", "histogram" },
      cli_prefix = "-",
      key_prefix = "-",
    })
    :option_if(not in_merge, "S", "gpg-sign", "", "Sign using gpg", { key_prefix = "-" })
    :group_heading_if(not in_merge, "Actions")
    :action_if(not in_merge, "m", "Merge", actions.merge)
    :action_if(not in_merge, "e", "Merge and edit message", actions.merge_edit)
    :action_if(not in_merge, "n", "Merge but don't commit", actions.merge_nocommit)
    :action_if(not in_merge, "a", "Absorb") -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L158
    :new_action_group_if(not in_merge, "")
    :action_if(not in_merge, "p", "Preview merge") -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L225
    :group_heading_if(not in_merge, "")
    :action_if(not in_merge, "s", "Squash merge", actions.squash)
    :action_if(not in_merge, "i", "Dissolve") -- https://github.com/magit/magit/blob/main/lisp/magit-merge.el#L131
    :env(env)
    :build()

  p:show()

  return p
end

return M
