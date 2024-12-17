local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local Path = require("plenary.path")

---@class NeogitGitFiles
local M = {}

---@return string[]
function M.all()
  return git.cli["ls-files"].full_name.deleted.modified.exclude_standard.deduplicate.call({
    hidden = true,
  }).stdout
end

---@return string[]
function M.untracked()
  return git.cli["ls-files"].others.exclude_standard.call({ hidden = true }).stdout
end

---@param opts? { with_dir: boolean }
---@return string[]
function M.all_tree(opts)
  opts = opts or {}
  local files = git.cli["ls-tree"].full_tree.name_only.recursive.args("HEAD").call({ hidden = true }).stdout

  if opts.with_dir then
    local dirs = {}

    for _, path in ipairs(files) do
      local dir = vim.fs.dirname(path) .. Path.path.sep
      dirs[dir] = true
    end

    files = util.merge(files, vim.tbl_keys(dirs))
    table.sort(files)
  end

  return files
end

---@return string[]
function M.diff(commit)
  return git.cli.diff.name_only.args(commit .. "...").call({ hidden = true }).stdout
end

---@return string
function M.relpath_from_repository(path)
  local result = git.cli["ls-files"].others.cached.modified.deleted.full_name
    .args(path)
    .call { hidden = true, ignore_error = true }

  return result.stdout[1]
end

---@param path string
---@return boolean
function M.is_tracked(path)
  return git.cli["ls-files"].error_unmatch.files(path).call({ hidden = true, ignore_error = true }).code == 0
end

---@param paths string[]
---@return boolean
function M.untrack(paths)
  return git.cli.rm.cached.files(unpack(paths)).call({ hidden = true }).code == 0
end

---@param from string
---@param to string
---@return boolean
function M.move(from, to)
  return git.cli.mv.args(from, to).call().code == 0
end

return M
