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
    { "HelpPopup", "Help", popups.help.create },
    { "DiffPopup", "Diff", popups.diff.create },
    { "PullPopup", "Pull", popups.pull.create },
    { "RebasePopup", "Rebase", popups.rebase.create },
    { "MergePopup", "Merge", popups.merge.create },
    { "PushPopup", "Push", popups.push.create },
    { "CommitPopup", "Commit", popups.commit.create },
    { "LogPopup", "Log", popups.log.create },
    { "CherryPickPopup", "Apply", popups.cherry_pick.create },
    { "BranchPopup", "Branch", popups.branch.create },
    { "FetchPopup", "Fetch", popups.fetch.create },
    { "ResetPopup", "Reset", popups.reset.create },
    { "RevertPopup", "Revert", popups.revert.create },
    { "RemotePopup", "Remote", popups.remote.create },
    { "InitRepo", "Init", require("neogit.lib.git").init.init_repo },
    {
      "StashPopup",
      "Stash",
      function()
        popups.stash.create(env.get_stash())
      end,
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
