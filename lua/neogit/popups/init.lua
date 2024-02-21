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
  return {
    { "HelpPopup", "Help", M.open("help") },
    { "DiffPopup", "Diff", M.open("diff") },
    { "PullPopup", "Pull", M.open("pull") },
    { "RebasePopup", "Rebase", M.open("rebase") },
    { "MergePopup", "Merge", M.open("merge") },
    { "PushPopup", "Push", M.open("push") },
    { "CommitPopup", "Commit", M.open("commit") },
    { "IgnorePopup", "Ignore", M.open("ignore") },
    { "TagPopup", "Tag", M.open("tag") },
    { "LogPopup", "Log", M.open("log") },
    { "CherryPickPopup", "Cherry Pick", M.open("cherry_pick") },
    { "BranchPopup", "Branch", M.open("branch") },
    { "FetchPopup", "Fetch", M.open("fetch") },
    { "ResetPopup", "Reset", M.open("reset") },
    { "RevertPopup", "Revert", M.open("revert") },
    { "RemotePopup", "Remote", M.open("remote") },
    { "WorktreePopup", "Worktree", M.open("worktree") },
    { "StashPopup", "Stash", M.open("stash") },
  }
end

return M
