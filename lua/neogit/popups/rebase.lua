local M = {}

local cli = require("neogit.lib.git.cli")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

function M.create()
  local p = popup.builder()
    :name("NeogitRebasePopup")
    :action("p", "Rebase onto master", function()
      cli.rebase.args("master").call_sync()
    end)
    :action("e", "Rebase onto elsewhere", function()
      local branch = git.branch.prompt_for_branch(git.branch.get_all_branches())
        cli.rebase.args(branch).call_sync()
    end)
    :build()

  p:show()

  return p
end

return M
