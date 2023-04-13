local status = require("neogit.status")
local stash_lib = require("neogit.lib.git.stash")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

function M.create(stash)
  local p = popup
    .builder()
    :name("NeogitStashPopup")
    :switch("u", "include-untracked", "Also save untracked files", false)
    :switch("a", "all", "Also save untracked and ignored files", false)

    :group_heading("Stash")
    :action("z", "both", function()
      stash_lib.stash_all()
      status.refresh(true, "stash_both")
    end)
    :action("i", "index", function()
      stash_lib.stash_index()
      status.refresh(true, "stash_index")
    end)
    :action("w", "worktree", false)
    :action("x", "keeping index", false)
    :action("P", "push", function(popup)
      local files = git.cli["ls-files"].full_name.deleted.modified.exclude_standard.deduplicate.call_sync():trim().stdout
      local files = FuzzyFinderBuffer.new(files):open_sync({ allow_multi = true })
      if not files or not files[1] then
        return
      end

      stash_lib.push(popup:get_arguments(), files)
      status.refresh(true, "stash_push")
    end)

    :new_action_group("Snapshot")
    :action("Z", "both", false)
    :action("I", "index", false)
    :action("W", "worktree", false)
    :action("r", "to wip ref", false)

    :new_action_group_if(stash and stash.name, "Use")
    :action_if(stash and stash.name, "p", "pop", function(popup)
      stash_lib.pop(popup.state.env.stash.name)
      status.refresh(true, "stash_pop")
    end)
    :action_if(stash and stash.name, "a", "apply", function(popup)
      stash_lib.apply(popup.state.env.stash.name)
      status.refresh(true, "stash_apply")
    end)
    :action_if(stash and stash.name, "d", "drop", function(popup)
      stash_lib.drop(popup.state.env.stash.name)
      status.refresh(true, "stash_drop")
    end)

    :new_action_group("Inspect")
    :action("l", "List", false)
    :action("v", "Show", false)

    :new_action_group("Transform")
    :action("b", "Branch", false)
    :action("B", "Branch here", false)
    :action("f", "Format patch", false)

    :env({ stash = stash })
    :build()

  p:show()

  return p
end

return M
