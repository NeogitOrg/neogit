local M = {}

---@param name string
--@param get_args nil|fun(): any
--- Creates a curried function which will open the popup with the given name when called
--- Extra arguments are supplied to popup.`create()`
function M.open(name, get_args)
  return function()
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
  end
end

--- Returns an array useful for creating mappings for the available popups
---@return table<string, Mapping>
function M.mappings_table()
  local config = require("neogit.config")
  return {
    ["HelpPopup"] = M.open("help", function()
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
    ["DiffPopup"] = M.open("diff"),
    ["PullPopup"] = M.open("pull"),
    ["RebasePopup"] = M.open("rebase", function()
      local status = require("neogit.status")
      local line = status.status_buffer:get_current_line()
      return { line[1]:match("^(%x%x%x%x%x%x%x+)") }
    end),
    ["MergePopup"] = M.open("merge"),
    ["PushPopup"] = M.open("push"),
    ["CommitPopup"] = M.open("commit"),
    ["LogPopup"] = M.open("log"),
    ["CherryPickPopup"] = M.open("cherry_pick", function()
      local selection = nil

      if vim.api.nvim_get_mode().mode == "V" then
        local status = require("neogit.status")
        selection = status.get_selected_commits()
      end

      return { commits = selection }
    end),
    -- { "nv", a.void(cherry_pick), true },
    ["StashPopup"] = M.open("stash", function()
      local status = require("neogit.status")
      local line = status.status_buffer:get_current_line()
      return {
        name = line[1]:match("^(stash@{%d+})"),
      }
    end),
    ["RevertPopup"] = M.open("revert", function()
      local status = require("neogit.status")
      local line = status.status_buffer:get_current_line()
      return { commits = { line[1]:match("^(%x%x%x%x%x%x%x+)") } }
    end),
    ["BranchPopup"] = M.open("branch"),
    ["FetchPopup"] = M.open("fetch"),
    ["RemotePopup"] = M.open("remote"),
    ["ResetPopup"] = M.open("reset"),
  }
end

function M.test()
  M.open("echo", function()
    return "a", "b"
  end)()
end

return M
