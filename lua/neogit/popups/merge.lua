local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")
local merge = require("neogit.lib.git.merge")

local M = {}
local a = require("plenary.async")

function M.create()
  local status = require("neogit.status")
  local p = popup
    .builder()
    :name("NeogitMergePopup")
    :action_if(status and status.repo.merge.head, "m", "Continue merge", function()
      merge.continue()
      a.util.scheduler()
      status.refresh(true, "merge_continue")
    end)
    :action_if(status and status.repo.merge.head, "a", "Abort merge", function()
      merge.abort()
      a.util.scheduler()
      status.refresh(true, "merge_continue")
    end)
    :action(
      "m",
      "Merge",
      a.void(function(popup)
        local branches = git.branch.get_all_branches()
        local BranchSelectViewBuffer = require("neogit.buffers.branch_select_view")
        local branch = BranchSelectViewBuffer.new(branches):open_async()
        if not branch then
          return
        end

        merge.merge(branch, popup:get_arguments())
        a.util.scheduler()
        status.refresh(true, "merge")
      end)
    )
    :build()

  p:show()

  return p
end

return M
