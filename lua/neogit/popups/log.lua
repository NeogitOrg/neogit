local popup = require("neogit.lib.popup")
local Buffer = require("neogit.lib.buffer")
local git = require("neogit.lib.git")
local a = require('plenary.async_lib')
local async, await = a.async, a.await

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

local show_in_buffer = async(function (commits)
  await(a.scheduler())
  Buffer.create({
    name = "NeogitLog",
    filetype = "NeogitLog",
    initialize = function(buffer)
      local result = commits_to_string(commits)
      buffer:set_lines(0, -1, false, result)
    end
  })
end)

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
            a.scope(function ()
              local commits = await(git.log.list(popup.to_cli()))
              await(show_in_buffer(commits))
            end)
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
            a.scope(function ()
              local output = await(
                git.cli.log
                  .oneline
                  .args(unpack(popup.get_arguments()))
                  .for_range('HEAD')
                  .call())
              local commits = git.log.parse_log(output)
              await(show_in_buffer(commits))
            end)
          end
        },
      },
      {
        {
          key = "L",
          description = "Log local branches",
          callback = function(popup)
            a.scope(function ()
              local output = await(
                git.cli.log
                  .oneline
                  .args(unpack(popup.get_arguments()))
                  .branches
                  .call())
              local commits = git.log.parse_log(output)
              await(show_in_buffer(commits))
            end)
          end
        },
        {
          key = "b",
          description = "Log all branches",
          callback = function(popup)
            a.scope(function ()
              local output = await(
                git.cli.log
                  .oneline
                  .args(unpack(popup.get_arguments()))
                  .branches
                  .remotes
                  .call())
              local commits = git.log.parse_log(output)
              await(show_in_buffer(commits))
            end)
          end
        },
        {
          key = "a",
          description = "Log all references",
          callback = function(popup)
            a.scope(function ()
              local output = await(
                git.cli.log
                  .oneline
                  .args(unpack(popup.get_arguments()))
                  .all
                  .call())
              local commits = git.log.parse_log(output)
              await(show_in_buffer(commits))
            end)
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
