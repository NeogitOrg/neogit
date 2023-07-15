local M = {}

---@param name string
--@param get_args nil|fun(): any
--- Creates a curried function which will open the popup with the given name when called
--- Extra arguments are supplied to popup.`create()`
function M.open(name, get_args)
  local async = require("plenary.async")
  return async.void(function()
    local ok, value = pcall(require, "neogit.popups." .. name)
    if ok then
      assert(value)
      local args = {}

      if get_args then
        args = { get_args() }
      end

      value.create(table.unpack(args))
    else
      local notification = require("neogit.lib.notification")
      notification.create(string.format("No such popup: %q", name), vim.log.levels.ERROR)
    end
  end)
end

--- Returns an array useful for creating mappings for the available popups
---@return table<string, Mapping>
function M.mappings_table()
  local config = require("neogit.config")
  return {
    {
      "HelpPopup",
      "Help",
      M.open("help", function()
        local status = require("neogit.status")
        local line = status.status_buffer:get_current_line()

        return {
          get_stash = function()
            return {
              name = line[1]:match("^(stash@{%d+})"),
            }
          end,
          use_magit_keybindings = config.values.use_magit_keybindings,
        }
      end),
    },
    { "DiffPopup", "Diff", M.open("diff") },
    { "PullPopup", "Pull", M.open("pull") },
    {
      "RebasePopup",
      "Rebase",
      M.open("rebase", function()
        local status = require("neogit.status")
        local line = status.status_buffer:get_current_line()
        return { line[1]:match("^(%x%x%x%x%x%x%x+)") }
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
        M.open("cherry_pick", function()
          local selection = nil

          if vim.api.nvim_get_mode().mode == "V" then
            local status = require("neogit.status")
            selection = status.get_selected_commits()
          end

          return { commits = selection }
        end),
        true,
      },
    },
    {
      "StashPopup",
      "Stash",
      M.open("stash", function()
        local status = require("neogit.status")
        local line = status.status_buffer:get_current_line()
        return {
          name = line[1]:match("^(stash@{%d+})"),
        }
      end),
    },
    {
      "RevertPopup",
      "Revert",
      M.open("revert", function()
        local status = require("neogit.status")
        local line = status.status_buffer:get_current_line()
        return { commits = { line[1]:match("^(%x%x%x%x%x%x%x+)") } }
      end),
    },
    { "BranchPopup", "Branch", M.open("branch") },
    { "FetchPopup", "Fetch", M.open("fetch") },
    { "RemotePopup", "Remote", M.open("remote") },
    { "ResetPopup", "Reset", M.open("reset") },
  }
end

function M.test()
  M.open("echo", function()
    return "a", "b"
  end)()
end

return M
