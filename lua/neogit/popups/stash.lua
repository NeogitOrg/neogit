local a = require 'plenary.async_lib'
local status = require 'neogit.status'
local stash_lib = require 'neogit.lib.git.stash'
local popup = require('neogit.lib.popup')

local await = a.await

local M = {}

function M.create(stash)
  local p = popup.builder()
    :name("NeogitStashPopup")
    :switch("a", "all", "", false)
    :switch("u", "include-untracked", "", false)
    :action("z", "both", function()
      await(stash_lib.stash_all())
      await(status.refresh(true))
    end)
    :action("i", "index", function()
      await(stash_lib.stash_index())
      await(status.refresh(true))
    end)
    :new_action_group()
    :action_if(stash and stash.name, "p", "pop", function(popup)
      await(stash_lib.pop(popup.state.env.stash.name))
      await(status.refresh(true))
    end)
    :action_if(stash and stash.name, "a", "apply", function(popup)
      await(stash_lib.apply(popup.state.env.stash.name))
      await(status.refresh(true))
    end)
    :action_if(stash and stash.name, "d", "drop", function(popup)
      await(stash_lib.drop(popup.state.env.stash.name))
      await(status.refresh(true))
    end)
    :env({ stash = stash })
    :build()

  p:show()

  return p
end

return M
