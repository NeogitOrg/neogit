local cli = require("neogit.lib.git.cli")

local M = {}

function M.all()
  return cli["ls-files"].full_name.deleted.modified.exclude_standard.deduplicate.call_sync():trim().stdout
end

function M.all_tree()
  return cli["ls-tree"].full_tree.name_only.recursive.args("HEAD").call_sync():trim().stdout
end

function M.diff(commit)
  return cli.diff.name_only.args(commit .. "...").call_sync():trim().stdout
end

return M
