local M = {}

local util = require("neogit.lib.util")
local NONE = function() end

local status_mappings = vim.tbl_add_reverse_lookup(require("neogit.config").values.mappings.status)

local function present(commands)
  local presenter = util.map(commands, function(command)
    local cmd, name, fn = unpack(command)

    return { name = name, key = status_mappings[cmd], fn = fn }
  end)

  table.sort(presenter, function(a, b)
    return a.key:lower() < b.key:lower()
  end)

  return presenter
end

M.popups = function(env)
  local popups = require("neogit.popups")

  return present {
    { "HelpPopup", "Help", popups.open("help") },
    { "DiffPopup", "Diff", popups.open("diff") },
    { "PullPopup", "Pull", popups.open("pull") },
    { "RebasePopup", "Rebase", popups.open("rebase") },
    { "MergePopup", "Merge", popups.open("merge") },
    { "PushPopup", "Push", popups.open("push") },
    { "CommitPopup", "Commit", popups.open("commit") },
    { "LogPopup", "Log", popups.open("log") },
    { "CherryPickPopup", "Apply", popups.open("cherry_pick") },
    { "BranchPopup", "Branch", popups.open("branch") },
    { "FetchPopup", "Fetch", popups.open("fetch") },
    { "ResetPopup", "Reset", popups.open("reset") },
    { "RevertPopup", "Revert", popups.open("revert") },
    { "RemotePopup", "Remote", popups.open("remote") },
    { "InitRepo", "Init", require("neogit.lib.git").init.init_repo },
    {
      "StashPopup",
      "Stash",
      popups.open("stash", env.get_stash),
    },
    {
      "CommandHistory",
      "History",
      function()
        require("neogit.buffers.git_command_history"):new():show()
      end,
    },
  }
end

M.actions = function()
  return present {
    { "Stage", "Stage", NONE },
    { "StageUnstaged", "Stage-Unstaged", NONE },
    { "StageAll", "Stage all", NONE },
    { "Unstage", "Unstage", NONE },
    { "UnstageStaged", "Unstage-Staged", NONE },
    { "Discard", "Discard", NONE },
  }
end

M.essential = function()
  return present {
    {
      "RefreshBuffer",
      "Refresh",
      function()
        require("neogit.status").refresh(true, "user_refresh")
      end,
    },
    { "GoToFile", "Go to file", NONE },
    { "Toggle", "Toggle", NONE },
  }
end

return M
