local M = {}

local util = require("neogit.lib.util")
local NONE = function() end

-- Using deep extend this way creates a copy of the mapping values
local status_mappings = require("neogit.config").get_copy().mappings.status

local function present(commands)
  local presenter = util.map(commands, function(command)
    local cmd, name, fn = unpack(command)

    --- Handle the longer table mapping form (mode, func, esc)
    if type(fn) == "table" then
      fn = fn[2]
    end

    return { name = name, key = status_mappings[cmd], fn = fn }
  end)

  table.sort(presenter, function(a, b)
    return a.key:lower() < b.key:lower()
  end)

  return presenter
end

M.popups = function()
  local popups = require("neogit.popups")

  local items = vim.list_extend({
    {

      "CommandHistory",
      "History",
      function()
        require("neogit.buffers.git_command_history"):new():show()
      end,
    },
    { "InitRepo", "Init", require("neogit.lib.git").init.init_repo },
  }, popups.mappings_table())

  return present(items)
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
