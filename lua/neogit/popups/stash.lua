local a = require 'plenary.async_lib'
local async, await, void = a.async, a.await, a.void
local status = require 'neogit.status'
local popup = require('neogit.lib.popup')
local stash = require('neogit.lib.git.stash')

local M = {}

function M.create(stash)
  local p = popup.builder()
    :name("NeogitStashPopup")
    :switch("a", "all", "", false)
    :switch("u", "include-untracked", "", false)
    :action("z", "both", function()
      await(stash.stash_all())
      await(status.refresh(true))
    end)
    :action("i", "index", function()
      await(stash.stash_index())
      await(status.refresh(true))
    end)
    :new_action_row()
    :action_if(stash and stash.name, "p", "pop", function(popup)
      await(stash.pop(popup.env.stash.name))
      await(status.refresh(true))
    end)
    :action_if(stash and stash.name, "a", "apply", function(popup)
      await(stash.apply(popup.env.stash.name))
      await(status.refresh(true))
    end)
    :action_if(stash and stash.name, "d", "drop", function(popup)
      await(stash.apply(popup.env.stash.name))
      await(status.refresh(true))
    end)
    :env({ stash = stash })
    :build()

  p:show()

  return p
end

return M
