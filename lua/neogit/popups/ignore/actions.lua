local M = {}
local Path = require("plenary.path")

---@param path
---@param rules string[]
local function add_rules(path, rules)
  path:write(table.concat(rules, "\n") .. "\n", "a+", 438)
end

local operation = require("neogit.operations")
M.shared = operation("ignore_shared", function(popup)
  local git_root = popup.state.env.git_root
  local rules = vim.tbl_map(function(v)
    return Path:new(v):make_relative(git_root)
  end, popup.state.env.paths)

  add_rules(Path:new(git_root, "/.gitignore"), rules)
end)

M.private = operation("ignore_private", function(popup)
  local git_root = popup.state.env.git_root
  local rules = vim.tbl_map(function(v)
    return Path:new(v):make_relative(git_root)
  end, popup.state.env.paths)

  add_rules(Path:new(git_root .. "/.git/info/exclude"), rules)
end)

M.at_subdirectory = operation("ignore_subdirectory", function(popup)
  for _, path in ipairs(popup.state.env.paths) do
    local path = Path:new(path)
    local parent = path:parent()

    add_rules(path:parent() .. "/.gitignore", { path:make_relative(parent) })
  end
end)

return M
