local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.log.actions")

local M = {}

function M.create()
  -- TODO: Need to figure out how this works
  -- :switch("h", "header", "Show header", { cli_prefix = "++" })
  -- :switch("p", "patch", "Show diffs")
  -- :switch("s", "stat", "Show diffstats")

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
    :option("-", "", "", "Limit to files", {
      key_prefix = "-",
      separator = "",
      fn = actions.limit_to_files,
    })
    :switch("f", "follow", "Follow renames when showing single-file log")
    :arg_heading("Commit Ordering")
    :switch("r", "reverse", "Reverse order", { incompatible = { "graph", "color" } })
    :switch("o", "topo", "Order commits by", {
      cli_suffix = "-order",
      options = {
        { display = "", value = "" },
        { display = "topo", value = "topo" },
        { display = "author-date", value = "author-date" },
        { display = "date", value = "date" },
      },
    })
    :arg_heading("Formatting")
    :switch("g", "graph", "Show graph", {
      enabled = true,
      internal = true,
      incompatible = { "reverse" },
      dependant = { "color" },
    })
    :switch("c", "color", "Show graph in color", { internal = true, incompatible = { "reverse" } })
    :switch("d", "decorate", "Show refnames", { enabled = true, internal = true })
    :switch("S", "show-signature", "Show signatures", { key_prefix = "=" })
    :group_heading("Log")
    :action("l", "current", actions.log_current)
    :action("h", "HEAD", actions.log_head)
    :action("u", "related")
    :action("o", "other", actions.log_other)
    :new_action_group()
    :action("L", "local branches", actions.log_local_branches)
    :action("b", "all branches", actions.log_all_branches)
    :action("a", "all references", actions.log_all_references)
    :action("B", "matching branches")
    :action("T", "matching tags")
    :action("m", "merged")
    :new_action_group("Reflog")
    :action("r", "current", actions.reflog_current)
    :action("H", "HEAD", actions.reflog_head)
    :action("O", "other", actions.reflog_other)
    :new_action_group("Other")
    :action("s", "shortlog")
    :build()

  p:show()

  return p
end

return M
