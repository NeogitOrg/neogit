local M = {}

local util = require("neogit.lib.util")

local status_mappings = vim.tbl_add_reverse_lookup(require("neogit.config").values.mappings.status)

local function present(commands)
  local presenter = util.map(vim.tbl_keys(commands), function(cmd)
    return {
      name = cmd,
      key = status_mappings[cmd],
      fn = commands[cmd],
    }
  end)

  table.sort(presenter, function(a, b)
    return a.key:lower() < b.key:lower()
  end)

  return presenter
end

M.popups = function(env)
  return present {
    ["HelpPopup"] = require("neogit.popups.help").create,
    ["DiffPopup"] = require("neogit.popups.diff").create,
    ["PullPopup"] = require("neogit.popups.pull").create,
    ["RebasePopup"] = require("neogit.popups.rebase").create,
    ["MergePopup"] = require("neogit.popups.merge").create,
    ["PushPopup"] = require("neogit.popups.push").create,
    ["CommitPopup"] = require("neogit.popups.commit").create,
    ["LogPopup"] = require("neogit.popups.log").create,
    ["CherryPickPopup"] = require("neogit.popups.cherry_pick").create,
    ["BranchPopup"] = require("neogit.popups.branch").create,
    ["FetchPopup"] = require("neogit.popups.fetch").create,
    ["ResetPopup"] = require("neogit.popups.reset").create,
    ["RemotePopup"] = require("neogit.popups.remote").create,
    ["StashPopup"] = function()
      require("neogit.popups.stash").create(env.get_stash())
    end,
    ["CommandHistory"] = function()
      require("neogit.buffers.git_command_history"):new():show()
    end,
  }
end

M.actions = function()
  return present {
    ["Stage"] = function() end,
    ["StageUnstaged"] = function() end,
    ["StageAll"] = function() end,
    ["Unstage"] = function() end,
    ["UnstageStaged"] = function() end,
    ["Discard"] = function() end,
  }
end

M.essential = function()
  return present {
    ["RefreshBuffer"] = function()
      require("neogit.status").refresh(true, "user_refresh")
    end,
    ["GoToFile"] = function() end,
    ["Toggle"] = function() end,
  }
end

return M
