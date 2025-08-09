local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local config = require("neogit.config")
local event = require("neogit.lib.event")

---@class NeogitGitStash
local M = {}

function M.list_refs()
  local result = git.cli.reflog.show.format("%h").args("stash").call { ignore_error = true }
  if result:failure() then
    return {}
  else
    return result.stdout
  end
end

---@param args string[]
function M.stash_all(args)
  local result = git.cli.stash.push.files(".").arg_list(args).call()
  event.send("Stash", { success = result:success() })
end

function M.stash_index()
  local result = git.cli.stash.staged.call()
  event.send("Stash", { success = result:success() })
end

function M.stash_keep_index()
  local result = git.cli.stash.keep_index.files(".").call()
  event.send("Stash", { success = result:success() })
end

---@param args string[]
---@param files string[]
function M.push(args, files)
  local result = git.cli.stash.push.arg_list(args).files(unpack(files)).call()
  event.send("Stash", { success = result:success() })
end

function M.pop(stash)
  local result = git.cli.stash.apply.index.args(stash).call()

  if result:success() then
    git.cli.stash.drop.args(stash).call()
  else
    git.cli.stash.apply.args(stash).call()
  end

  event.send("Stash", { success = result:success() })
end

function M.apply(stash)
  local result = git.cli.stash.apply.index.args(stash).call()

  if result:failure() then
    git.cli.stash.apply.args(stash).call()
  end

  event.send("Stash", { success = result:success() })
end

function M.drop(stash)
  local result = git.cli.stash.drop.args(stash).call()
  event.send("Stash", { success = result:success() })
end

function M.list()
  return git.cli.stash.args("list").call({ hidden = true }).stdout
end

function M.rename(stash)
  local current = git.log.message(stash)
  local message = input.get_user_input("rename", { prepend = current })
  if message then
    local oid = git.rev_parse.abbreviate_commit(stash)
    git.cli.stash.drop.args(stash).call()
    git.cli.stash.store.message(message).args(oid).call()
  end
end

---@class StashItem
---@field idx number string the id of the stash i.e. stash@{7}
---@field name string
---@field date string timestamp
---@field rel_date string relative timestamp
---@field message string the message associated with each stash.

function M.register(meta)
  meta.update_stashes = function(state)
    state.stashes.items = util.map(M.list(), function(line)
      local idx, message = line:match("stash@{(%d*)}: (.*)")

      idx = tonumber(idx)
      assert(idx, "indx cannot be nil")

      ---@class StashItem
      local item = {
        idx = idx,
        name = line,
        message = message,
      }

      -- These calls can be somewhat expensive, so lazy load them
      setmetatable(item, {
        __index = function(self, key)
          if key == "rel_date" then
            self.rel_date = git.cli.log
              .max_count(1)
              .format("%cr")
              .args(("stash@{%s}"):format(idx))
              .call({ hidden = true }).stdout[1]

            return self.rel_date
          elseif key == "date" then
            self.date = git.cli.log
              .max_count(1)
              .format("%cd")
              .args("--date=format:" .. config.values.log_date_format)
              .args(("stash@{%s}"):format(idx))
              .call({ hidden = true }).stdout[1]

            return self.date
          elseif key == "oid" then
            self.oid = git.rev_parse.oid("stash@{" .. idx .. "}")
            return self.oid
          end
        end,
      })

      return item
    end)
  end
end

return M
