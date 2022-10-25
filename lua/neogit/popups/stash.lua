local status = require("neogit.status")
local stash_lib = require("neogit.lib.git.stash")
local popup = require("neogit.lib.popup")

local M = {}

function M.create(stash)
  local p = popup
    .builder()
    :name("NeogitStashPopup")
    :switch("a", "all", "", false)
    :switch("u", "include-untracked", "", false)
    :action("z", "both", function()
      stash_lib.stash_all()
      status.refresh(true, "stash_both")
    end)
    :action("i", "index", function()
      stash_lib.stash_index()
      status.refresh(true, "stash_index")
    end)
    :new_action_group()
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
    :env({ stash = stash })
    :build()

  p:show()

  return p
end

return M
