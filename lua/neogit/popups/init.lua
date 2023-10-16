local M = {}
local git = require("neogit.lib.git")

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
      local notification = require("neogit.lib.notification")
      notification.error(string.format("Failed to load popup: %q\n%s", name, value))
    end
  end
end

--- Returns an array useful for creating mappings for the available popups
---@return table<string, Mapping>
function M.mappings_table()
  local util = require("neogit.lib.util")

  ---@param commit CommitLogEntry|nil
  ---@return string|nil
  local function commit_oid(commit)
    return commit and commit.oid
  end

  ---@param commits CommitLogEntry[]
  ---@return string[]
  local function map_commits(commits)
    return vim.tbl_map(function(v)
      return v.oid
    end, commits)
  end

  return {
    { "HelpPopup", "Help", M.open("help") },
    { "DiffPopup", "Diff", M.open("diff") },
    { "PullPopup", "Pull", M.open("pull") },
    {
      "RebasePopup",
      "Rebase",
      M.open("rebase", function(f)
        f { commit = commit_oid(require("neogit.status").get_selection().commit) }
      end),
    },
    { "MergePopup", "Merge", M.open("merge") },
    {
      "PushPopup",
      "Push",
      M.open("push", function(f)
        f { commit = commit_oid(require("neogit.status").get_selection().commit) }
      end),
    },
    {
      "CommitPopup",
      "Commit",
      M.open("commit", function(f)
        f { commit = commit_oid(require("neogit.status").get_selection().commit) }
      end),
    },
    {
      "IgnorePopup",
      "Ignore",
      {
        "nv",
        M.open("ignore", function(f)
          f {
            paths = util.filter_map(require("neogit.status").get_selection().items, function(v)
              return v.absolute_path
            end),
            git_root = git.repo.state.git_root,
          }
        end),
      },
    },
    { "TagPopup", "Tag", M.open("tag") },
    { "LogPopup", "Log", M.open("log") },
    {
      "CherryPickPopup",
      "Cherry Pick",
      {
        "nv",
        M.open("cherry_pick", function(f)
          f { commits = util.reverse(map_commits(require("neogit.status").get_selection().commits)) }
        end),
      },
    },
    {
      "BranchPopup",
      "Branch",
      {
        "nv",
        M.open("branch", function(f)
          f { commits = map_commits(require("neogit.status").get_selection().commits) }
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
          f { commit = commit_oid(require("neogit.status").get_selection().commit) }
        end),
      },
    },
    {
      "RevertPopup",
      "Revert",
      {
        "nv",
        M.open("revert", function(f)
          f { commits = util.reverse(map_commits(require("neogit.status").get_selection().commits)) }
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
