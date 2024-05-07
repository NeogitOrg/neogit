local git = require("neogit.lib.git")

---@class NeogitGitFiles
local M = {}

function M.all()
  return git.cli["ls-files"].full_name.deleted.modified.exclude_standard.deduplicate.call_sync({
    hidden = true,
  }).stdout
end

function M.untracked()
  return git.cli["ls-files"].others.exclude_standard.call_sync({ hidden = true }).stdout
end

function M.all_tree()
  return git.cli["ls-tree"].full_tree.name_only.recursive.args("HEAD").call_sync({ hidden = true }).stdout
end

function M.diff(commit)
  return git.cli.diff.name_only.args(commit .. "...").call_sync({ hidden = true }).stdout
end

function M.relpath_from_repository(path)
  local result = git.cli["ls-files"].others.cached.modified.deleted.full_name
    .args(path)
    .show_popup(false)
    .call { hidden = true }

  return result.stdout[1]
end

function M.is_tracked(path)
  return git.cli["ls-files"].error_unmatch.files(path).call({ hidden = true, ignore_error = true }).code == 0
end

function M.untrack(paths)
  return git.cli.rm.cached.files(unpack(paths)).call({ hidden = true }).code == 0
end

return M
