local M = {}

local Path = require("plenary.path")
local git = require("neogit.lib.git")
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

function M.shared_toplevel(popup)
  local ignore_file = Path:new(git.repo.worktree_root, ".gitignore")
  local rules = make_rules(popup, git.repo.worktree_root)

  add_rules(ignore_file, rules)
end

function M.shared_subdirectory(popup)
  local choice = input.get_user_input("Ignore sub-directory", { completion = "dir" })
  if choice then
    local subdirectory = Path:new(vim.uv.cwd(), choice)
    local ignore_file = subdirectory:joinpath(".gitignore")
    local rules = make_rules(popup, tostring(subdirectory))

    add_rules(ignore_file, rules)
  end
end

function M.private_local(popup)
  local ignore_file = git.repo:git_path("info", "exclude")
  local rules = make_rules(popup, git.repo.worktree_root)

  add_rules(ignore_file, rules)
end

function M.private_global(popup)
  local ignore_file = Path:new(git.config.get_global("core.excludesfile"):read())
  local rules = make_rules(popup, git.repo.worktree_root)

  add_rules(ignore_file, rules)
end

return M
