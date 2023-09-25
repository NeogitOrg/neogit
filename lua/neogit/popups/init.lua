local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")
local M = {}

---@param name string
---@param f nil|fun(create: fun(...)): any
--- Creates a curried function which will open the popup with the given name when called
function M.open(name, f)
  f = f or function(c)
    c()
  end

  return function()
    local ok, value = pcall(require, "neogit.popups." .. name)
    if ok then
      assert(value, "popup is not nil")
      assert(value.create, "popup has create function")

      f(value.create)
    else
      notification.error(string.format("Failed to load popup: %q\n%s", name, value))
    end
  end
end

--- Returns an array useful for creating mappings for the available popups
---@return table<string, Mapping>
function M.mappings_table()
  return {
    { "HelpPopup", "Help", M.open("help") },
    { "DiffPopup", "Diff", M.open("diff") },
    { "PullPopup", "Pull", M.open("pull") },
    {
      "RebasePopup",
      "Rebase",
      M.open("rebase", function(f)
        local commit = require("neogit.status").get_selected_commits()[1]
        f { commit = commit and commit.oid }
      end),
    },
    { "MergePopup", "Merge", M.open("merge") },
    { "PushPopup", "Push", M.open("push") },
    {
      "CommitPopup",
      "Commit",
      M.open("commit", function(f)
        local commit = require("neogit.status").get_selected_commits()[1]
        f { commit = commit and commit.oid }
      end),
    },
    { "LogPopup", "Log", M.open("log") },
    {
      "CherryPickPopup",
      "Cherry Pick",
      {
        "nv",
        M.open("cherry_pick", function(f)
          local commits = util.filter_map(require("neogit.status").get_selected_commits(), function(c)
            return c.oid
          end)
          f { commits = util.reverse(commits) }
        end),
      },
    },
    {
      "BranchPopup",
      "Branch",
      {
        "nv",
        M.open("branch", function(f)
          local commits = util.filter_map(require("neogit.status").get_selected_commits(), function(c)
            return c.oid
          end)
          f { revisions = commits }
        end),
      },
    },
    { "FetchPopup", "Fetch", M.open("fetch") },
    {
      "ResetPopup",
      "Reset",
      {
        "nv",
        M.open("reset", function(f)
          local commit = require("neogit.status").get_selected_commits()[1]
          f { commit = commit and commit.oid }
        end),
      },
    },
    {
      "RevertPopup",
      "Revert",
      {
        "nv",
        M.open("revert", function(f)
          local commits = util.filter_map(require("neogit.status").get_selected_commits(), function(c)
            return c.oid
          end)
          f { commits = util.reverse(commits) }
        end),
      },
    },
    { "RemotePopup", "Remote", M.open("remote") },
    {
      "StashPopup",
      "Stash",
      M.open("stash", function(f)
        f { name = require("neogit.status").status_buffer:get_current_line()[1]:match("^(stash@{%d+})") }
      end),
    },
  }
end

function M.test()
  M.open("echo", function(f)
    f("a", "b")
  end)()
end

return M
