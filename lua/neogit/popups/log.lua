local popup = require("neogit.lib.popup")
local util = require("neogit.lib.util")
local buffer = require("neogit.buffer")
local git = require("neogit.git")

local function commits_to_string(commits)
  local result = {}
  local previous_level = 0

  for _, commit in pairs(commits) do
    local branch = "*"
    if previous_level > commit.level then
      table.insert(result, string.rep(" ", 7) .. string.rep(" |", commit.level + 1) .. "/")
    elseif previous_level < commit.level then
      table.insert(result, string.rep(" ", 7) .. string.rep(" |", previous_level + 1) .. "\\")
    end
    for _=1,commit.level do
      branch = "| " .. branch
    end
    if commit.remote == "" then
      table.insert(result, string.format("%s %s %s", commit.hash, branch, commit.message))
    else
      table.insert(result, string.format("%s %s %s %s", commit.hash, branch, commit.remote, commit.message))
    end
    previous_level = commit.level
  end

  return result
end

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
            local cmd = "git log --oneline " .. popup.to_cli()
            local output = vim.fn.systemlist(cmd)
            local commits = git.parse_log(output)

            buffer.create({
              name = "NeogitLog",
              initialize = function()
                local result = commits_to_string(commits)
                vim.fn.matchadd("Comment", "^[a-z0-9]\\{7}\\ze ")
                vim.api.nvim_put(result, "l", false, false)
              end
            })
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
          callback = function() end
        },
      },
      {
        {
          key = "L",
          description = "Log local branches",
          callback = function() end
        },
        {
          key = "b",
          description = "Log all branches",
          callback = function() end
        },
        {
          key = "a",
          description = "Log all references",
          callback = function() end
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
