local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local config = require("neogit.config")

---@class NeogitGitStash
local M = {}

---@param success boolean
local function fire_stash_event(success)
  vim.api.nvim_exec_autocmds("User", {
    pattern = "NeogitStash",
    modeline = false,
    data = { success = success },
  })
end

function M.list_refs()
  local result = git.cli.reflog.show.format("%h").args("stash").call { ignore_error = true }
  if result.code > 0 then
    return {}
  else
    return result.stdout
  end
end

---@param args string[]
function M.stash_all(args)
  local result = git.cli.stash.push.files(".").arg_list(args).call()
  fire_stash_event(result.code == 0)
end

function M.stash_index()
  local result = git.cli.stash.staged.call()
  fire_stash_event(result.code == 0)
end

function M.stash_keep_index()
  local result = git.cli.stash.keep_index.files(".").call()
  fire_stash_event(result.code == 0)
end

---@param args string[]
---@param files string[]
function M.push(args, files)
  local result = git.cli.stash.push.arg_list(args).files(unpack(files)).call()
  fire_stash_event(result.code == 0)
end

function M.pop(stash)
  local result = git.cli.stash.apply.index.args(stash).call()

  if result.code == 0 then
    git.cli.stash.drop.args(stash).call()
  else
    git.cli.stash.apply.args(stash).call()
  end

  fire_stash_event(result.code == 0)
end

function M.apply(stash)
  local result = git.cli.stash.apply.index.args(stash).call()

  if result.code ~= 0 then
    git.cli.stash.apply.args(stash).call()
  end

  fire_stash_event(result.code == 0)
end

function M.drop(stash)
  local result = git.cli.stash.drop.args(stash).call()
  fire_stash_event(result.code == 0)
end

function M.list()
  return git.cli.stash.args("list").call({ hidden = true }).stdout
end

function M.rename(stash)
  local message = input.get_user_input("New name")
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
        oid = git.rev_parse.oid("stash@{" .. idx .. "}"),
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
          end
        end,
      })

      return item
    end)
  end
end

return M
