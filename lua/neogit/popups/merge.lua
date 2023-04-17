local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")
local input = require("neogit.lib.input")

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
      :action("m", "Commit merge", function()
        git.merge.continue()
        a.util.scheduler()
        status.refresh(true, "merge_continue")
      end)
      :action("a", "Abort merge", function()
        if not input.get_confirmation("Abort merge?", { values = { "&Yes", "&No" }, default = 2 }) then
          return
        end

        git.merge.abort()
        a.util.scheduler()
        status.refresh(true, "merge_abort")
      end)
  else
    p:switch("f", "ff-only", "Fast-forward only", { incompatible = { "no-ff" } })
      :switch("n", "no-ff", "No fast-forward", { incompatible = { "ff-only" } })
      :switch("b", "Xignore-space-change", "Ignore changes in amount of whitespace", { cli_prefix = "-" })
      :switch("w", "Xignore-all-space", "Ignore whitespace when comparing lines", { cli_prefix = "-" })
      :option("s", "strategy", "", "Strategy", {
        choices = { "resolve", "recursive", "octopus", "ours", "subtree" },
      })
      :option("X", "strategy-option", "", "Strategy Option", {
        choices = { "ours", "theirs", "patience" },
      })
      :option("A", "Xdiff-algorithm", "", "Diff algorithm", {
        cli_prefix = "-",
        choices = { "default", "minimal", "patience", "histogram" },
      })
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
      :group_heading("")
      :action("i", "Dissolve")
  end

  p = p:build()
  p:show()

  return p
end

return M
