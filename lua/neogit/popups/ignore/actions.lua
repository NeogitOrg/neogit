local M = {}

local Path = require("plenary.path")
local git = require("neogit.lib.git")
local operation = require("neogit.operations")
local util = require("neogit.lib.util")
local input = require("neogit.lib.input")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local function make_rules(popup, relative)
  local files = util.merge(popup.state.env.paths, git.files.untracked())

  return util.deduplicate(vim.tbl_map(function(v)
    if vim.startswith(v, relative) then
      return Path:new(v):make_relative(relative)
    else
      return v
    end
  end, files))
end

---@param path Path
---@param rules string[]
local function add_rules(path, rules)
  local selected = FuzzyFinderBuffer.new(rules)
    :open_async { allow_multi = true, prompt_prefix = "File or pattern to ignore" }

  if not selected or #selected == 0 then
    return
  end

  path:write(table.concat(selected, "\n") .. "\n", "a+")
end

M.shared_toplevel = operation("ignore_shared", function(popup)
  local ignore_file = Path:new(git.repo.git_root, ".gitignore")
  local rules = make_rules(popup, git.repo.git_root)

  add_rules(ignore_file, rules)
end)

M.shared_subdirectory = operation("ignore_subdirectory", function(popup)
  local subdirectory = input.get_user_input("Ignore sub-directory", { completion = "dir" })
  if subdirectory then
    subdirectory = Path:new(vim.loop.cwd(), subdirectory)

    local ignore_file = subdirectory:joinpath(".gitignore")
    local rules = make_rules(popup, tostring(subdirectory))

    add_rules(ignore_file, rules)
  end
end)

M.private_local = operation("ignore_private", function(popup)
  local ignore_file = git.repo:git_path("info", "exclude")
  local rules = make_rules(popup, git.repo.git_root)

  add_rules(ignore_file, rules)
end)

M.private_global = operation("ignore_private_global", function(popup)
  local ignore_file = Path:new(git.config.get_global("core.excludesfile"):read())
  local rules = make_rules(popup, git.repo.git_root)

  add_rules(ignore_file, rules)
end)

return M
