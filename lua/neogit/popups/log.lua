local popup = require("neogit.lib.popup")
local LogViewBuffer = require("neogit.buffers.log_view")
local git = require("neogit.lib.git")
local log = require("neogit.lib.git.log")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitLogPopup")
    :switch("g", "graph", "Show graph", { enabled = true, parse = false })
    :switch("c", "color", "Show graph in color", { enabled = true, parse = false })
    :switch("d", "decorate", "Show refnames", { enabled = true })
    :switch("S", "show-signature", "Show signatures")
    -- :switch("h", "header", "Show header", { cli_prefix = "++" })
    :switch("u", "patch", "Show diffs")
    :switch("s", "stat", "Show diffstats")
    :switch("D", "simplify-by-decoration", "Simplify by decoration")
    :switch("f", "follow", "Follow renames when showing single-file log")
    :switch("r", "reverse", "Reverse order")
    -- :switch("o", "xxx-order", "Order commits by", false) TODO: Build multi-selector switch
    :option("n", "max-count", "256", "Limit number of commits")
    :option("f", "count", "", "Limit to files")
    :option("a", "author", "", "Limit to author")
    :option("g", "grep", "", "Search messages")
    -- :option("G", "G", "", "Search changes") TODO: Needs to get send in as `-Gsomething`
    -- :option("S", "S", "", "Search occurrences") `-Ssomething`
    -- :option("L", "L", "", "Trace line evolution") `-Lsomething`
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
