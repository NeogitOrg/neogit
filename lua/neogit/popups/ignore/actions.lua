local M = {}

---@param path string
---@param rules string[]
local function add_rules(path, rules)
  local async = require("plenary.async")
  local notification = require("neogit.lib.notification")

  local err, fd = async.uv.fs_open(path, "a+", 438)
  if err then
    return notification.error(string.format("Failed to read ignore file %q\n\n%s", path, err))
  end

  async.uv.fs_write(fd, table.concat(rules, "\n") .. "\n")

  local err = async.uv.fs_close(fd)
  if err then
    return notification.error(string.format("Failed to close file %q", path))
  end

  -- notification.info(string.format("Added %d rules to %q", #rules, path))
end

local operation = require("neogit.operations")
M.shared = operation("ignore_shared", function(popup)
  local Path = require("plenary.path")

  local git_root = popup.state.env.git_root
  local rules = vim.tbl_map(function(v)
    return tostring(Path:new(v):make_relative(git_root))
  end, popup.state.env.paths)

  add_rules(git_root .. "/.gitignore", rules)
end)

M.private = operation("ignore_private", function(popup)
  local Path = require("plenary.path")

  local git_root = popup.state.env.git_root
  local rules = vim.tbl_map(function(v)
    return tostring(Path:new(v):make_relative(git_root))
  end, popup.state.env.paths)

  add_rules(git_root .. "/.git/info/exclude", rules)
end)

M.at_subdirectory = operation("ignore_subdirectory", function(popup)
  local Path = require("plenary.path")

  for _, path in ipairs(popup.state.env.paths) do
    local path = Path:new(path)
    local parent = tostring(path:parent())

    add_rules(tostring(parent) .. "/.gitignore", { tostring(path:make_relative(parent)) })
  end
end)

return M
