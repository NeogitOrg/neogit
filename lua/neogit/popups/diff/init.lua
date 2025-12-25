local M = {}

local config = require("neogit.config")
local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.diff.actions")

function M.create(env)
  local diff_viewer = config.get_diff_viewer()
  local commit_selected = (env.section and env.section.name == "log") and type(env.item.name) == "string"

  local p = popup
    .builder()
    :name("NeogitDiffPopup")
    :group_heading("Diff")
    :action_if(diff_viewer and env.item, "d", "this", actions.this)
    :action_if(diff_viewer and commit_selected, "h", "this..HEAD", actions.this_to_HEAD)
    :action_if(diff_viewer, "r", "range", actions.range)
    :action("p", "paths")
    :new_action_group()
    :action_if(diff_viewer, "u", "unstaged", actions.unstaged)
    :action_if(diff_viewer, "s", "staged", actions.staged)
    :action_if(diff_viewer, "w", "worktree", actions.worktree)
    :new_action_group("Show")
    :action_if(diff_viewer, "c", "Commit", actions.commit)
    :action_if(diff_viewer, "t", "Stash", actions.stash)
    :env(env)
    :build()

  p:show()

  return p
end

return M
