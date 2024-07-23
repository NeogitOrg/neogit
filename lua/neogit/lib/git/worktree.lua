local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local Path = require("plenary.path")

---@class NeogitGitWorktree
local M = {}

---Creates new worktree at path for ref
---@param ref string branch name, tag name, HEAD, etc.
---@param path string absolute path
---@return boolean
function M.add(ref, path, params)
  local result = git.cli.worktree.add.arg_list(params or {}).args(path, ref).call { await = true }
  return result.code == 0
end

---Moves an existing worktree
---@param worktree string absolute path of existing worktree
---@param destination string absolute path for where to move worktree
---@return boolean
function M.move(worktree, destination)
  local result = git.cli.worktree.move.args(worktree, destination).call { await = true }
  return result.code == 0
end

---Removes a worktree
---@param worktree string absolute path of existing worktree
---@param args? table
---@return boolean
function M.remove(worktree, args)
  local result =
    git.cli.worktree.remove.args(worktree).arg_list(args or {}).call { ignore_error = true, await = true }
  return result.code == 0
end

---@class Worktree
---@field main boolean
---@field path string
---@field head string
---@field type string
---@field ref string

---Lists all worktrees for a git repo
---@param opts? table
---@return Worktree[]
function M.list(opts)
  opts = opts or { include_main = true }
  local list = git.cli.worktree.list.args("--porcelain").call().stdout

  local worktrees = {}
  for i = 1, #list, 3 do
    local path = list[i]:match("^worktree (.-)$")
    local head = list[i]:match("^HEAD (.-)$")
    local type, ref = list[i + 2]:match("^([^ ]+) (.+)$")

    if path then
      local main = Path.new(path, ".git"):is_dir()
      table.insert(worktrees, {
        head = head,
        type = type,
        ref = ref,
        main = main,
        path = path,
      })
    end
  end

  if not opts.include_main then
    worktrees = util.filter(worktrees, function(worktree)
      if not worktree.main then
        return worktree
      end
    end)
  end

  return worktrees
end

---Finds main worktree
---@return Worktree
function M.main()
  return util.find(M.list { include_main = true }, function(worktree)
    return worktree.main
  end)
end

return M
