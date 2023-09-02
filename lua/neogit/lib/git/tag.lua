local cli = require("neogit.lib.git.cli")

local M = {}

--- Outputs a list of tags locally
---@return table|nil List of tags.
function M.list()
  local revisions = cli.tag.list.call():trim().stdout
  if #revisions == 0 then
    return nil
  end
  return revisions
end

--- Deletes a list of tags
---@param tags table List of tags
---@return boolean Successfully deleted
function M.delete(tags)
  local result = cli.tag.delete.arg_list(unpack(tags)).call():trim()
  return result.code == 0
end

--- Show a list of tags under a selected ref
---@param remote string
---@return table
function M.list_remote(remote)
  return cli["ls-remote"].tags.args(remote).call():trim().stdout
end

return M
