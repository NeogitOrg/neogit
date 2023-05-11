local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

local LogViewBuffer = require("neogit.buffers.log_view")
local ReflogViewBuffer = require("neogit.buffers.reflog_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitLogPopup")
    :arg_heading("Commit Limiting")
    :option("n", "max-count", "256", "Limit number of commits", { default = "256" })
    :option("A", "author", "", "Limit to author")
    :option("F", "grep", "", "Search messages")
    :option("s", "since", "", "Limit to commits since")
    :option("u", "until", "", "Limit to commits until")
    :switch("G", "G", "Search changes", { user_input = true, cli_prefix = "-" })
    :switch("S", "S", "Search occurrences", { user_input = true, cli_prefix = "-" })
    :switch("L", "L", "Trace line evolution", { user_input = true, cli_prefix = "-" })
    :switch("m", "no-merges", "Omit merges", { key_prefix = "=" })
    :switch("p", "first-parent", "First parent", { key_prefix = "=" })
    :arg_heading("History Simplification")
    :switch("D", "simplify-by-decoration", "Simplify by decoration")
    -- TODO: Activation should be "--", and should open file-select fuzzy finder, defaulting to the filepath under the
    -- cursor if there is one. Needs to get passed into #files() down the line, too.
    -- :option("-", "--", "", "Limit to files")
    :switch(
      "f",
      "follow",
      "Follow renames when showing single-file log"
    )
    :arg_heading("Commit Ordering")
    -- :switch("o", "xxx-order", "Order commits by", false) TODO: Build multi-selector switch
    :switch(
      "r",
      "reverse",
      "Reverse order"
    )
    :arg_heading("Formatting")
    :switch("g", "graph", "Show graph", { enabled = true, internal = true })
    :switch("c", "color", "Show graph in color")
    :switch(
      "d",
      "decorate",
      "Show refnames",
      { enabled = true }
    )
    :switch("S", "show-signature", "Show signatures", { key_prefix = "=" })
    -- :switch("h", "header", "Show header", { cli_prefix = "++" }) TODO: Need to figure out how this works
    -- :switch("p", "patch", "Show diffs")
    :switch(
      "s",
      "stat",
      "Show diffstats"
    )
    :group_heading("Log")
    :action("l", "current", function(popup)
      LogViewBuffer.new(git.log.list(popup:get_arguments()), popup:get_internal_arguments()):open()
    end)
    :action("h", "HEAD", function(popup)
      LogViewBuffer.new(
        git.log.list(util.merge(popup:get_arguments(), { "HEAD" })),
        popup:get_internal_arguments()
      )
        :open()
    end)
    :action("u", "related")
    :action("o", "other")
    :new_action_group()
    :action("L", "local branches", function(popup)
      LogViewBuffer.new(
        git.log.list(util.merge(popup:get_arguments(), {
          git.branch.current() and "" or "HEAD",
          "--branches",
        })),
        popup:get_internal_arguments()
      ):open()
    end)
    :action("b", "all branches", function(popup)
      LogViewBuffer.new(
        git.log.list(util.merge(popup:get_arguments(), {
          git.branch.current() and "" or "HEAD",
          "--branches",
          "--remotes",
        })),
        popup:get_internal_arguments()
      ):open()
    end)
    :action("a", "all references", function(popup)
      LogViewBuffer.new(
        git.log.list(util.merge(popup:get_arguments(), {
          git.branch.current() and "" or "HEAD",
          "--all",
        })),
        popup:get_internal_arguments()
      ):open()
    end)
    :action("B", "matching branches")
    :action("T", "matching tags")
    :action("m", "merged")
    :new_action_group("Reflog")
    :action("r", "current", function(popup)
      ReflogViewBuffer.new(git.reflog.list(git.branch.current(), popup:get_arguments())):open()
    end)
    :action("H", "HEAD", function(popup)
      ReflogViewBuffer.new(git.reflog.list("HEAD", popup:get_arguments())):open()
    end)
    :action("O", "other", function(popup)
      local branch = FuzzyFinderBuffer.new(git.branch.get_local_branches()):open_sync()
      if branch then
        ReflogViewBuffer.new(git.reflog.list(branch, popup:get_arguments())):open()
      end
    end)
    :new_action_group("Other")
    :action("s", "shortlog")
    :build()

  p:show()

  return p
end

return M
