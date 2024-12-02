local actions = require("neogit.popups.stash.actions")
local popup = require("neogit.lib.popup")

local M = {}

function M.create(stash)
  local p = popup
    .builder()
    :name("NeogitStashPopup")
    :switch("u", "include-untracked", "Also save untracked files", {
      incompatible = { "all" },
    })
    :switch("a", "all", "Also save untracked and ignored files", {
      incompatible = { "include-untracked" },
    })
    :group_heading("Stash")
    :action("z", "both", actions.both)
    :action("i", "index", actions.index)
    :action("w", "worktree")
    :action("x", "keeping index", actions.keep_index)
    :action("P", "push", actions.push)
    :new_action_group("Snapshot")
    :action("Z", "both")
    :action("I", "index")
    :action("W", "worktree")
    :action("r", "to wip ref")
    :new_action_group("Use")
    :action("p", "pop", actions.pop)
    :action("a", "apply", actions.apply)
    :action("d", "drop", actions.drop)
    :new_action_group("Inspect")
    :action("l", "List", actions.list)
    :action("v", "Show")
    :new_action_group("Transform")
    :action("b", "Branch")
    :action("B", "Branch here")
    :action("m", "Rename", actions.rename)
    :action("f", "Format patch")
    :env({ stash = stash })
    :build()

  p:show()

  return p
end

return M
