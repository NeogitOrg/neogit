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
  return result:success()
end

--- Show a list of tags under a selected ref
---@param remote string
---@return table
function M.list_remote(remote)
  return git.cli["ls-remote"].tags.args(remote).call({ hidden = true }).stdout
end

---Find tags that point at an object ID
---@param oid string
---@return string[]
function M.for_commit(oid)
  return git.cli.tag.points_at(oid).call({ hidden = true }).stdout
end

--- Returns the highest tag by version sort, or nil if no tags exist.
---@return string|nil
function M.highest()
  local tags = git.cli.tag.list.args("--sort=version:refname").call({ hidden = true }).stdout
  if #tags == 0 then
    return nil
  end
  return tags[#tags]
end

--- Returns the annotation message of a tag, or nil if lightweight or empty.
---@param tagname string
---@return string|nil
function M.message(tagname)
  local result =
    git.cli["for-each-ref"].format("%(contents)").args("refs/tags/" .. tagname).call { hidden = true }
  local msg = table.concat(result.stdout, "\n"):gsub("%s+$", "")
  return msg ~= "" and msg or nil
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
