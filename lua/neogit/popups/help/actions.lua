local M = {}

local util = require("neogit.lib.util")
local NONE = function() end

local status_mappings = require("neogit.config").get_reversed_status_maps()
local popup_mappings = require("neogit.config").get_reversed_popup_maps()

local function present(commands)
  local presenter = util.map(commands, function(command)
    local cmd, name, fn = unpack(command)

    --- Handle the longer table mapping form (mode, func, esc)
    if type(fn) == "table" then
      fn = fn[2]
    end

    local keymap = status_mappings[cmd]
    if not keymap or keymap == "<nop>" then
      keymap = popup_mappings[cmd]
    end

    if type(keymap) == "table" and next(keymap) then
      return { { name = name, keys = keymap, cmp = table.concat(keymap):lower(), fn = fn } }
    else
      return { { name = name, keys = {}, cmp = "", fn = fn } }
    end
  end)

  presenter = util.flatten(presenter)

  table.sort(presenter, function(a, b)
    return a.cmp < b.cmp
  end)

  return presenter
end

M.popups = function(env)
  local popups = require("neogit.popups")
  local items = {
    {
      "CommandHistory",
      "History",
      function()
        require("neogit.buffers.git_command_history"):new():show()
      end,
    },
    { "InitRepo", "Init", require("neogit.lib.git").init.init_repo },
    -- { "HelpPopup", "Help", M.open("help") },
    { "DiffPopup", "Diff", popups.open("diff", function(p)
      p(env.diff)
    end) },
    { "PullPopup", "Pull", popups.open("pull", function(p)
      p(env.pull)
    end) },
    { "RebasePopup", "Rebase", popups.open("rebase", function(p)
      p(env.rebase)
    end) },
    { "MergePopup", "Merge", popups.open("merge", function(p)
      p(env.merge)
    end) },
    { "PushPopup", "Push", popups.open("push", function(p)
      p(env.push)
    end) },
    { "CommitPopup", "Commit", popups.open("commit", function(p)
      p(env.commit)
    end) },
    { "IgnorePopup", "Ignore", popups.open("ignore", function(p)
      p(env.ignore)
    end) },
    { "TagPopup", "Tag", popups.open("tag", function(p)
      p(env.tag)
    end) },
    { "LogPopup", "Log", popups.open("log", function(p)
      p(env.log)
    end) },
    {
      "CherryPickPopup",
      "Cherry Pick",
      popups.open("cherry_pick", function(p)
        p(env.cherry_pick)
      end),
    },
    { "BranchPopup", "Branch", popups.open("branch", function(p)
      p(env.branch)
    end) },
    { "BisectPopup", "Bisect", popups.open("bisect", function(p)
      p(env.bisect)
    end) },
    { "FetchPopup", "Fetch", popups.open("fetch", function(p)
      p(env.fetch)
    end) },
    { "ResetPopup", "Reset", popups.open("reset", function(p)
      p(env.reset)
    end) },
    { "RevertPopup", "Revert", popups.open("revert", function(p)
      p(env.revert)
    end) },
    { "RemotePopup", "Remote", popups.open("remote", function(p)
      p(env.remote)
    end) },
    { "WorktreePopup", "Worktree", popups.open("worktree", function(p)
      p(env.worktree)
    end) },
    { "StashPopup", "Stash", popups.open("stash", function(p)
      p(env.stash)
    end) },
    { "Command", "Command", require("neogit.buffers.status.actions").n_command(nil) },
  }

  return present(items)
end

M.actions = function()
  return present {
    { "Stage", "Stage", NONE },
    { "StageUnstaged", "Stage unstaged", NONE },
    { "StageAll", "Stage all", NONE },
    { "Unstage", "Unstage", NONE },
    { "UnstageStaged", "Unstage all", NONE },
    { "Discard", "Discard", NONE },
    { "Untrack", "Untrack", NONE },
  }
end

M.essential = function()
  return present {
    {
      "RefreshBuffer",
      "Refresh",
      function()
        local status = require("neogit.buffers.status")
        if status.is_open() then
          status.instance():dispatch_refresh(nil, "user_refresh")
        end
      end,
    },
    { "GoToFile", "Go to file", NONE },
    { "Toggle", "Toggle", NONE },
  }
end

return M
