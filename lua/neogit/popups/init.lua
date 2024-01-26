local M = {}
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

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

---@param name string
---@return string|string[]
---Returns the keymapping for a popup
function M.mapping_for(name)
  local mappings = require("neogit.config").get_reversed_popup_maps()

  if mappings[name] then
    return mappings[name]
  else
    return {}
  end
end

--- Returns an array useful for creating mappings for the available popups
---@return table<string, Mapping>
function M.mappings_table()
  ---@return string|nil
  local function get_selected_commit_oid()
    local s = require("neogit.status").get_selection()
    return s.item and s.item.commit and s.item.commit.oid
  end

  ---@return string[]
  local function get_selected_commit_oids()
    local s = require("neogit.status").get_selection()
    return vim.tbl_map(function(v)
      return v.oid
    end, s.commits)
  end

  return {
    { "HelpPopup", "Help", M.open("help") },
    {
      "DiffPopup",
      "Diff",
      M.open("diff", function(f)
        local section, item = require("neogit.status").get_current_section_item()

        f { section = section, item = item }
      end),
    },
    { "PullPopup", "Pull", M.open("pull") },
    {
      "RebasePopup",
      "Rebase",
      M.open("rebase", function(f)
        f { commit = get_selected_commit_oid() }
      end),
    },
    { "MergePopup", "Merge", M.open("merge") },
    {
      "PushPopup",
      "Push",
      M.open("push", function(f)
        f { commit = get_selected_commit_oid() }
      end),
    },
    {
      "CommitPopup",
      "Commit",
      M.open("commit", function(f)
        f { commit = get_selected_commit_oid() }
      end),
    },
    {
      "IgnorePopup",
      "Ignore",
      {
        "nv",
        M.open("ignore", function(f)
          local items = require("neogit.status").get_selection().items
          f {
            paths = util.filter_map(items, function(v)
              return v.absolute_path
            end),
            git_root = git.repo.git_root,
          }
        end),
      },
    },
    {
      "TagPopup",
      "Tag",
      M.open("tag", function(f)
        f { commit = get_selected_commit_oid() }
      end),
    },
    { "LogPopup", "Log", M.open("log") },
    {
      "CherryPickPopup",
      "Cherry Pick",
      {
        "nv",
        M.open("cherry_pick", function(f)
          f { commits = util.reverse(get_selected_commit_oids()) }
        end),
      },
    },
    {
      "BranchPopup",
      "Branch",
      {
        "nv",
        M.open("branch", function(f)
          f { commits = get_selected_commit_oids() }
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
          f { commit = get_selected_commit_oid() }
        end),
      },
    },
    {
      "RevertPopup",
      "Revert",
      {
        "nv",
        M.open("revert", function(f)
          f { commits = util.reverse(get_selected_commit_oids()) }
        end),
      },
    },
    { "RemotePopup", "Remote", M.open("remote") },
    { "WorktreePopup", "Worktree", M.open("worktree") },
    {
      "StashPopup",
      "Stash",
      M.open("stash", function(f)
        local line = require("neogit.status").status_buffer:get_current_line()[1]
        f { name = line:match("^(stash@{%d+})") }
      end),
    },
  }
end

return M
