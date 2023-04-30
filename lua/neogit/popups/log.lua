local popup = require("neogit.lib.popup")
local LogViewBuffer = require("neogit.buffers.log_view")
local git = require("neogit.lib.git")
local log = require("neogit.lib.git.log")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitLogPopup")
    -- Commit Limiting
    :option("n", "max-count", "256", "Limit number of commits")
    :option("A", "author", "", "Limit to author")
    :option("F", "grep", "", "Search messages")
    :switch("G", "G", "Search changes", { user_input = true, cli_prefix = "-" })
    :switch("S", "S", "Search occurrences", { user_input = true, cli_prefix = "-" })
    :switch("L", "L", "Trace line evolution", { user_input = true, cli_prefix = "-" })

    -- History Simplification
    :switch("D", "simplify-by-decoration", "Simplify by decoration")
    -- TODO: Activation should be "--", and should open file-select fuzzy finder, defaulting to the filepath under the
    -- cursor if there is one. Needs to get passed into #files() down the line, too.
    -- :option("-", "--", "", "Limit to files")
    :switch("f", "follow", "Follow renames when showing single-file log")

    -- Commit Ordering
    -- :switch("o", "xxx-order", "Order commits by", false) TODO: Build multi-selector switch
    :switch("r", "reverse", "Reverse order")

    -- Formatting
    :switch("g", "graph", "Show graph", { enabled = true, parse = false })
    -- :switch("c", "color", "Show graph in color", { enabled = true, parse = false })
    :switch("d", "decorate", "Show refnames", { enabled = true })
    :switch("S", "show-signature", "Show signatures", { key_prefix = "=" })
    -- :switch("h", "header", "Show header", { cli_prefix = "++" }) TODO: Need to figure out how this works
    :switch("p", "patch", "Show diffs")
    :switch("s", "stat", "Show diffstats")

    :group_heading("Log")
    :action("l", "current", function(popup)
      local result =
        git.cli.log.format("fuller").args("--graph", unpack(popup:get_arguments())).call_sync():trim()
      local parse_args = popup:get_parse_arguments()
      LogViewBuffer.new(log.parse(result.stdout), parse_args.graph):open()
    end)
    :action("h", "HEAD", function(popup)
      local result =
        git.cli.log.format("fuller").args(unpack(popup:get_arguments())).for_range("HEAD").call_sync()

      LogViewBuffer.new(log.parse(result.stdout)):open()
    end)
    :action("r", "related")
    :action("o", "other")
    :new_action_group()
    :action("L", "local branches")
    :action("b", "all branches", function(popup)
      local result =
        git.cli.log.format("fuller").args(unpack(popup:get_arguments())).branches.remotes.call_sync()
      LogViewBuffer.new(log.parse(result.stdout)):open()
    end)
    :action("a", "all references", function(popup)
      local result = git.cli.log.format("fuller").args(unpack(popup:get_arguments())).all.call_sync()
      LogViewBuffer.new(log.parse(result.stdout)):open()
    end)
    :new_action_group("Reflog")
    :action("r", "current")
    :action("H", "HEAD")
    :action("O", "other")
    :new_action_group("Other")
    :action("s", "shortlog")
    :build()

  p:show()

  return p
end

return M
