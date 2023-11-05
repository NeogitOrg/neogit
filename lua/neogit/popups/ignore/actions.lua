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
      return "/" .. Path:new(v):make_relative(relative)
    end
  end, files))
end

---@param path
---@param rules string[]
local function add_rules(path, rules)
  local selected = FuzzyFinderBuffer.new(rules)
    :open_async { allow_multi = true, prompt_prefix = " File or pattern to ignore > " }

  if not selected or #selected == 0 then
    return
  end

  path:write(table.concat(selected, "\n") .. "\n", "a+", 438)
end

-- stylua: ignore
M.shared_toplevel = operation("ignore_shared", function(popup)
  add_rules(
    Path:new(git.repo.git_root, ".gitignore"),
    make_rules(popup, git.repo.git_root)
  )
end)

M.shared_subdirectory = operation("ignore_subdirectory", function(popup)
  local subdirectory = input.get_user_input(" sub-directory > ", nil, "dir")
  if subdirectory then
    subdirectory = tostring(Path:new(vim.loop.cwd(), subdirectory))
    add_rules(Path:new(subdirectory, ".gitignore"), make_rules(popup, subdirectory))
  end
end)

-- stylua: ignore
M.private_local = operation("ignore_private", function(popup)
  add_rules(
    git.repo.git_path("info", "exclude"),
    make_rules(popup, git.repo.git_root)
  )
end)

-- stylua: ignore
M.private_global = operation("ignore_private_global", function(popup)
  add_rules(
    Path:new(git.config.get_global("core.excludesfile"):read()),
    make_rules(popup, git.repo.git_root)
  )
end)

return M
