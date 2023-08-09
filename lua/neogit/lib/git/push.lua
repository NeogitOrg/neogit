local cli = require("neogit.lib.git.cli")
local log = require("neogit.lib.git.log")
local util = require("neogit.lib.util")

local M = {}

---Pushes to the remote and handles password questions
---@param remote string
---@param branch string
---@param args string[]
---@return ProcessResult
function M.push_interactive(remote, branch, args)
  return cli.push.args(remote or "", branch or "").arg_list(args).call_interactive()
end

local function update_unmerged(state)
  state.upstream.unmerged.items = {}
  state.pushRemote.unmerged.items = {}

  if state.upstream.ref then
    state.upstream.unmerged.items = util.filter_map(log.list { "@{upstream}.." }, function(v)
      if v.oid then
        return {
          name = string.format("%s %s", v.oid:sub(1, 7), v.description[1] or "<empty>"),
          oid = v.oid,
          commit = v,
        }
      end
    end)
  end

  local pushRemote = require("neogit.lib.git").branch.pushRemote_ref()
  if pushRemote then
    state.pushRemote.unmerged.items = util.filter_map(log.list { pushRemote .. ".." }, function(v)
      if v.oid then
        return {
          name = string.format("%s %s", v.oid:sub(1, 7), v.description[1] or "<empty>"),
          oid = v.oid,
          commit = v,
        }
      end
    end)
  end
end

function M.register(meta)
  meta.update_unmerged = update_unmerged
end

return M
