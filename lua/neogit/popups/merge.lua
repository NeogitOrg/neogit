local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}
local a = require("plenary.async")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local function in_merge(status)
  return status and status.repo.rebase.head
end

function M.create()
  local status = require("neogit.status")
  local p = popup.builder():name("NeogitMergePopup")

  if in_merge(status) then
    p:group_heading("Actions")
      :action("m", "Continue", function()
        git.merge.continue()
        a.util.scheduler()
        status.refresh(true, "merge_continue")
      end)
      :action("a", "Abort", function()
        git.merge.abort()
        a.util.scheduler()
        status.refresh(true, "merge_continue")
      end)
  else
    p:switch("f", "ff-only", "Fast-forward only", false)
      :switch("n", "no-ff", "No fast-forward", false)
      :switch("b", "Xignore-space-change", "Ignore changes in amount of whitespace", false)
      :switch("w", "Xignore-all-space", "Ignore whirespace when comparing lines", false)
      :option("s", "strategy", "", "Strategy")
      :option("X", "strategy-option", "", "Strategy Option")
      :option("A", "Xdiff-algorithm", "", "Diff algorithm", { cli_flag = "-" })
      :option("S", "gpg-sign", "", "Sign using gpg")
      :group_heading("Actions")
      :action("m", "Merge", function(popup)
        local branch = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_sync()
        if not branch then
          return
        end

        git.merge.merge(branch, popup:get_arguments())
        a.util.scheduler()
        status.refresh(true, "merge")
      end)
      :action("e", "Merge and edit message")
      :action("n", "Merge but don't commit")
      :action("A", "Absorb")
      :new_action_group()
      :action("p", "Preview merge")
      :action("s", "Squash merge")
      :action("i", "Dissolve")
  end

  p = p:build()
  p:show()

  return p
end

return M
