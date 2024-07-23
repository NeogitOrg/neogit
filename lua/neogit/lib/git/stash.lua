local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")

---@class NeogitGitStash
local M = {}

---@param pattern string
local function fire_stash_event(pattern)
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false })
end

function M.list_refs()
  local result = git.cli.reflog.show.format("%h").args("stash").call { ignore_error = true }
  if result.code > 0 then
    return {}
  else
    return result.stdout
  end
end

function M.stash_all(args)
  git.cli.stash.arg_list(args).call { await = true }
  fire_stash_event("NeogitStash")
  -- this should work, but for some reason doesn't.
  --return perform_stash({ worktree = true, index = true })
end

function M.stash_index()
  git.cli.stash.staged.call { await = true }
  fire_stash_event("NeogitStash")
end

function M.stash_keep_index()
  local files = git.cli["ls-files"].call().stdout
  -- for some reason complains if not passed files,
  -- but this seems to be a git cli error; running:
  --    git --literal-pathspecs stash --keep-index
  -- fails with a bizarre error:
  -- error: pathspec ':/' did not match any file(s) known to git
  git.cli.stash.keep_index.files(unpack(files)).call { await = true }
  fire_stash_event("NeogitStash")
end

function M.push(args, files)
  git.cli.stash.push.arg_list(args).files(unpack(files)).call { await = true }
end

function M.pop(stash)
  local result = git.cli.stash.apply.index.args(stash).call { await = true }

  if result.code == 0 then
    git.cli.stash.drop.args(stash).call { await = true }
  else
    git.cli.stash.apply.args(stash).call { await = true }
  end

  fire_stash_event("NeogitStash")
end

function M.apply(stash)
  local result = git.cli.stash.apply.index.args(stash).call { await = true }

  if result.code ~= 0 then
    git.cli.stash.apply.args(stash).call { await = true }
  end

  fire_stash_event("NeogitStash")
end

function M.drop(stash)
  git.cli.stash.drop.args(stash).call { await = true }
  fire_stash_event("NeogitStash")
end

function M.list()
  return git.cli.stash.args("list").call({ hidden = true }).stdout
end

function M.rename(stash)
  local message = input.get_user_input("New name")
  if message then
    local oid = git.rev_parse.abbreviate_commit(stash)
    git.cli.stash.drop.args(stash).call { await = true }
    git.cli.stash.store.message(message).args(oid).call { await = true }
  end
end

---@class StashItem
---@field idx number string the id of the stash i.e. stash@{7}
---@field name string
---@field rel_date string relative timestamp
---@field message string the message associated with each stash.

function M.register(meta)
  meta.update_stashes = function(state)
    state.stashes.items = util.map(M.list(), function(line)
      local idx, message = line:match("stash@{(%d*)}: (.*)")

      ---@class StashItem
      return {
        rel_date = git.cli.log
          .max_count(1)
          .format("%cr")
          .args(("stash@{%s}"):format(idx))
          .call({ hidden = true }).stdout[1],
        idx = tonumber(idx),
        name = line,
        message = message,
      }
    end)
  end
end

return M
