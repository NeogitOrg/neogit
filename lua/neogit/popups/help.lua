local popup = require("neogit.lib.popup")
local status = require("neogit.status")
local git = require("neogit.lib.git")

local M = {}

function M.create(env)
  local m = env.use_magit_keybindings
  local p = popup
    .builder()
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
    :action("I", "Initialize Repo", function()
      git.init.init_repo()
    end)
    :action("r", "Rebase", function()
      require("neogit.popups.rebase").create()
    end)
    :new_action_group()
    :action("c", "Commit", function()
      require("neogit.popups.commit").create()
    end)
    :action("b", "Branch", function()
      require("neogit.popups.branch").create()
    end)
    :action("f", "Fetch", function()
      require("neogit.popups.fetch").create()
    end)
    :action("$", "Git Command History", function()
      require("neogit.buffers.git_command_history"):new():show()
    end)
    :action("<c-r>", "Refresh Status Buffer", function()
      status.refresh(true, "user_refresh")
    end)
    :env(env)
    :build()

  p:show()

  return p
end

return M
