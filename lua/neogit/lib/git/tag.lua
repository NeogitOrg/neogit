local git = require("neogit.lib.git")

---@class NeogitGitTag
local M = {}

--- Outputs a list of tags locally
---@return table List of tags.
function M.list()
  return git.cli.tag.list.call().stdout
end

--- Deletes a list of tags
---@param tags table List of tags
---@return boolean Successfully deleted
function M.delete(tags)
  local result = git.cli.tag.delete.arg_list(tags).call()
  return result.code == 0
end

--- Show a list of tags under a selected ref
---@param remote string
---@return table
function M.list_remote(remote)
  return git.cli["ls-remote"].tags.args(remote).call().stdout
end

return M
