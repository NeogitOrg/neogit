local git = require("neogit.lib.git")

local M = {}

---@param path string
---@param rules string[]
local function add_rules(path, rules)
  local uv = require("neogit.lib.uv")
  local async = require("plenary.async")
  local notification = require("neogit.lib.notification")

  print("Opening " .. path)
  local err, fd = async.uv.fs_open(path, "a+", 438)
  if err then
    return notification.error(string.format("Failed to read ignore file %q\n\n%s", path, err))
  end

  print("Writing rules")
  async.uv.fs_write(fd, table.concat(rules , "\n"))

  local err = async.uv.fs_close(fd)
  if err then
    return notification.error(string.format("Failed to close file %q", path))
  end

  notification.info(string.format("Added %d rules to %q", #rules, path))
end

function M.shared(popup)
  local Path = require("plenary.path")

  local current_dir = vim.fn.getcwd()
  local root = popup.state.env.git_root
  local rules = vim.tbl_map(function(v)
    return tostring(Path:new(current_dir, v):make_relative(root))
  end, popup.state.env.files)

  add_rules(root .. "/.gitignore", rules)
end

return M
