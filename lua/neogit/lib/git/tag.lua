local git = require("neogit.lib.git")

---@class NeogitGitTag
local M = {}

--- Outputs a list of tags locally
---@return table List of tags.
function M.list()
  return git.cli.tag.list.call({ hidden = true }).stdout
end

--- Deletes a list of tags
---@param tags table List of tags
---@return boolean Successfully deleted
function M.delete(tags)
  local result = git.cli.tag.delete.arg_list(tags).call { await = true }
  return result.code == 0
end

--- Show a list of tags under a selected ref
---@param remote string
---@return table
function M.list_remote(remote)
  return git.cli["ls-remote"].tags.args(remote).call({ hidden = true }).stdout
end

local tag_pattern = "(.-)%-([0-9]+)%-g%x+$"

function M.register(meta)
  meta.update_tags = function(state)
    state.head.tag = { name = nil, distance = nil, oid = nil }

    local tag = git.cli.describe.long.tags.args("HEAD").call({ hidden = true, ignore_error = true }).stdout
    if #tag == 1 then
      local tag, distance = tostring(tag[1]):match(tag_pattern)
      if tag and distance then
        state.head.tag = {
          name = tag,
          distance = tonumber(distance),
          oid = git.rev_parse.oid(tag),
        }
      end
    end
  end
end

return M
