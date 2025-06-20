local M = {}

local config = require("neogit.config")
local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.diff.actions")

function M.create(env)
  local diffview = config.check_integration("diffview")

  local p = popup
    .builder()
    :name("NeogitDiffPopup")
    :group_heading("Diff Working Tree/Index")
    :action_if(diffview, "d", "Current File/Selection", actions.this)
    :action_if(diffview, "w", "Worktree", actions.worktree)
    :action_if(diffview, "s", "Staged Changes (Index)", actions.staged)
    :action_if(diffview, "u", "Unstaged Changes (HEAD vs Worktree)", actions.unstaged)
    :new_action_group("Diff Ranges")
    :action_if(diffview, "b", "Branch Range", actions.branch_range)
    :action_if(diffview, "c", "Commit/Ref Range", actions.commit_range)
    :action_if(diffview, "t", "Tag Range", actions.tag_range)
    :action_if(diffview, "h", "HEAD to Commit/Ref", actions.head_to_commit_ref)
    :action_if(diffview, "r", "Custom Range (any ref)", actions.custom_range)
    :new_action_group("Diff Specific Types")
    :action_if(diffview, "S", "Stash", actions.stash)
    :action_if(diffview, "p", "Paths", actions.paths)
    :action_if(diffview, "f", "Files", actions.files)
    :env(env)
    :build()

  p:show()

  return p
end

return M
