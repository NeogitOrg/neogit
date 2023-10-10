local M = {}
local Path = require("plenary.path")
local git = require("neogit.lib.git")
local operation = require("neogit.operations")
local util = require("neogit.lib.util")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

---@param path
---@param rules string[]
local function add_rules(path, rules)
  rules = FuzzyFinderBuffer.new(util.merge(rules, git.files.untracked()))
    :open_async { allow_multi = true, prompt_prefix = " File or pattern to ignore > " }

  if not rules or #rules == 0 then
    return
  end

  path:write(table.concat(rules, "\n") .. "\n", "a+", 438)
end

M.shared_toplevel = operation("ignore_shared", function(popup)
  local git_root = git.repo.git_root

  local rules = vim.tbl_map(function(v)
    return Path:new(v):make_relative(git_root)
  end, popup.state.env.paths)

  add_rules(Path:new(git_root, "/.gitignore"), rules)
end)

M.shared_subdirectory = operation("ignore_subdirectory", function(popup)
  for _, path in ipairs(popup.state.env.paths) do
    local path = Path:new(path)
    local parent = path:parent()

    add_rules(Path:new(parent, "/.gitignore"), { path:make_relative(tostring(parent)) })
  end
end)

M.private_local = operation("ignore_private", function(popup)
  local git_path = git.repo.git_path()

  local rules = vim.tbl_map(function(v)
    return Path:new(v):make_relative()
  end, popup.state.env.paths)

  add_rules(Path:new(git_path, "/info/exclude"), rules)
end)

M.private_global = operation("ignore_private_global", function(popup)
  local rules = vim.tbl_map(function(v)
    return Path:new(v):make_relative()
  end, popup.state.env.paths)

  add_rules(Path:new(git.config.get_global("core.excludesfile"):read()), rules)
end)

return M
