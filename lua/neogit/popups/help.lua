local popup = require("neogit.lib.popup")

local M = {}

function M.create(env)
  local m = env.use_magit_keybindings
  local p = popup
    .builder()
    :group_heading("Commands")
    :name("NeogitHelpPopup")
    :action(m and "F" or "p", "Pull", function()
      require("neogit.popups.pull").create()
    end)
    :action("P", "Push", function()
      require("neogit.popups.push").create()
    end)
    :action("Z", "Stash", function()
      require("neogit.popups.stash").create(env.get_stash())
    end)
    :action("L", "Log", function()
      require("neogit.popups.log").create()
    end)
    :action("r", "Rebase", function()
      require("neogit.popups.rebase").create()
    end)
    :action("X", "Reset", function()
      require("neogit.popups.reset").create()
    end)
    :new_action_group()
    :action("c", "Commit", function()
      require("neogit.popups.commit").create()
    end)
    :action("b", "Branch", function()
      require("neogit.popups.branch").create()
    end)
    :action("A", "Cherry Pick", function()
      require("neogit.popups.cherry_pick").create()
    end)
    :action("f", "Fetch", function()
      require("neogit.popups.fetch").create()
    end)
    :action("$", "Git Command History", function()
      require("neogit.buffers.git_command_history"):new():show()
    end)
    :action("<c-r>", "Refresh Status Buffer", function()
      require("neogit.status").refresh(true, "user_refresh")
    end)
    :env(env)
    :build()

  p:show()

  return p
end

return M
