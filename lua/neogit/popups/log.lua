local popup = require("neogit.lib.popup")
local LogViewBuffer = require 'neogit.buffers.log_view'
local git = require("neogit.lib.git")
local log_lib = require 'neogit.lib.git.log'

local function create()
  popup.create(
    "NeogitLogPopup",
    {
      {
        key = "g",
        description = "Show graph",
        cli = "graph",
        enabled = true
      },
      {
        key = "c",
        description = "Show graph in color",
        cli = "color",
        enabled = true,
        parse = false
      },
      {
        key = "d",
        description = "Show refnames",
        cli = "decorate",
        enabled = true
      },
      {
        key = "S",
        description = "Show signatures",
        cli = "show-signature",
        enabled = false
      },
      {
        key = "u",
        description = "Show diffs",
        cli = "patch",
        enabled = false
      },
      {
        key = "s",
        description = "Show diffstats",
        cli = "stat",
        enabled = false
      },
      {
        key = "D",
        description = "Simplify by decoration",
        cli = "simplify-by-decoration",
        enabled = false
      },
      {
        key = "f",
        description = "Follow renames when showing single-file log",
        cli = "follow",
        enabled = false
      },
    },
    {
      {
        key = "n",
        description = "Limit number of commits",
        cli = "max-count",
        value = "256"
      },
      {
        key = "f",
        description = "Limit to files",
        cli = "-count",
        value = ""
      },
      {
        key = "a",
        description = "Limit to author",
        cli = "author",
        value = ""
      },
      {
        key = "g",
        description = "Search messages",
        cli = "grep",
        value = ""
      },
      {
        key = "G",
        description = "Search changes",
        cli = "",
        value = ""
      },
      {
        key = "S",
        description = "Search occurences",
        cli = "",
        value = ""
      },
      {
        key = "L",
        description = "Trace line evolution",
        cli = "",
        value = ""
      },
    },
    {
      {
        {
          key = "l",
          description = "Log current",
          callback = function(popup)
            local output = git.cli.log.args(unpack(popup.get_arguments())).call_sync()
            LogViewBuffer.new(log_lib.parse_log(output)):open()
          end
        },
        {
          key = "o",
          description = "Log other",
          callback = function() end
        },
        {
          key = "h",
          description = "Log HEAD",
          callback = function(popup)
            local output = 
              git.cli.log
                .oneline
                .args(unpack(popup.get_arguments()))
                .for_range('HEAD')
                .call_sync()

            LogViewBuffer.new(log_lib.parse_log(output)):open()
          end
        },
      },
      {
        {
          key = "L",
          description = "Log local branches",
          callback = function(popup)
            local output = 
              git.cli.log
                .oneline
                .args(unpack(popup.get_arguments()))
                .branches
                .call_sync()

            LogViewBuffer.new(log_lib.parse_log(output)):open()
          end
        },
        {
          key = "b",
          description = "Log all branches",
          callback = function(popup)
            local output = 
              git.cli.log
                .oneline
                .args(unpack(popup.get_arguments()))
                .branches
                .remotes
                .call_sync()
            LogViewBuffer.new(log_lib.parse_log(output)):open()
          end
        },
        {
          key = "a",
          description = "Log all references",
          callback = function(popup)
            local output = 
              git.cli.log
                .oneline
                .args(unpack(popup.get_arguments()))
                .all
                .call_sync()
            LogViewBuffer.new(log_lib.parse_log(output)):open()
          end
        },
      },
      {
        {
          key = "r",
          description = "Reflog current",
          callback = function() end
        },
        {
          key = "O",
          description = "Reflog other",
          callback = function() end
        },
        {
          key = "H",
          description = "Reflog HEAD",
          callback = function() end
        },
      }
    })
end

return {
  create = create
}
