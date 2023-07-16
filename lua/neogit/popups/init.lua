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
      local notification = require("neogit.lib.notification")
      notification.create(string.format("No such popup: %q", name), vim.log.levels.ERROR)
    end
  end
end

--- Returns an array useful for creating mappings for the available popups
---@return table<string, Mapping>
function M.mappings_table()
  local config = require("neogit.config")
  local async = require("plenary.async")
  return {
    {
      "HelpPopup",
      "Help",
      M.open("help", function(f)
        f {
          use_magit_keybindings = config.values.use_magit_keybindings,
        }
      end),
    },
    { "DiffPopup", "Diff", M.open("diff") },
    { "PullPopup", "Pull", M.open("pull") },
    {
      "RebasePopup",
      "Rebase",
      M.open("rebase", function(f)
        local status = require("neogit.status")
        local line = status.status_buffer:get_current_line()
        f { line[1]:match("^(%x%x%x%x%x%x%x+)") }
      end),
    },
    { "MergePopup", "Merge", M.open("merge") },
    { "PushPopup", "Push", M.open("push") },
    { "CommitPopup", "Commit", M.open("commit") },
    { "LogPopup", "Log", M.open("log") },
    {
      "CherryPickPopup",
      "Cherry Pick",
      {
        "nv",
        M.open(
          "cherry_pick",
          async.void(function(f)
            local selection = nil

            if vim.api.nvim_get_mode().mode == "V" then
              local status = require("neogit.status")
              selection = status.get_selected_commits()
            end

            f { commits = selection }
          end)
        ),
        true,
      },
    },
    { "BranchPopup", "Branch", M.open("branch") },
    { "FetchPopup", "Fetch", M.open("fetch") },
    { "ResetPopup", "Reset", M.open("reset") },
    {
      "RevertPopup",
      "Revert",
      M.open("revert", function(f)
        local status = require("neogit.status")
        local line = status.status_buffer:get_current_line()
        f { commits = { line[1]:match("^(%x%x%x%x%x%x%x+)") } }
      end),
    },
    { "RemotePopup", "Remote", M.open("remote") },
    {
      "StashPopup",
      "Stash",
      M.open("stash", function(f)
        local status = require("neogit.status")
        local line = status.status_buffer:get_current_line()
        f {
          name = line[1]:match("^(stash@{%d+})"),
        }
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
