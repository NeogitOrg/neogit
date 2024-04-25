local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")

---@class NeogitGitStash
local M = {}

local function perform_stash(include)
  if not include then
    return
  end

  local index =
    git.cli["commit-tree"].no_gpg_sign.parent("HEAD").tree(git.cli["write-tree"].call().stdout).call().stdout

  git.cli["read-tree"].merge.index_output(".git/NEOGIT_TMP_INDEX").args(index).call()

  if include.worktree then
    local files = git.cli.diff.no_ext_diff.name_only
      .args("HEAD")
      .env({
        GIT_INDEX_FILE = ".git/NEOGIT_TMP_INDEX",
      })
      .call()

    git.cli["update-index"].add.remove
      .files(unpack(files))
      .env({
        GIT_INDEX_FILE = ".git/NEOGIT_TMP_INDEX",
      })
      .call()
  end

  local tree = git.cli["commit-tree"].no_gpg_sign
    .parents("HEAD", index)
    .tree(git.cli["write-tree"].call())
    .env({
      GIT_INDEX_FILE = ".git/NEOGIT_TMP_INDEX",
    })
    .call()

  git.cli["update-ref"].create_reflog.args("refs/stash", tree).call()

  -- selene: allow(empty_if)
  if include.worktree and include.index then
    -- disabled because stashing both worktree and index via this function
    -- leaves a malformed stash entry, so reverting the changes is
    -- destructive until fixed.
    --
    --cli.reset
    --.hard
    --.commit('HEAD')
    --.call()
  elseif include.index then
    local diff = git.cli.diff.no_ext_diff.cached.call().stdout[1] .. "\n"

    git.cli.apply.reverse.cached.input(diff).call()
    git.cli.apply.reverse.input(diff).call()
  end
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
  git.cli.stash.arg_list(args).call()
  -- this should work, but for some reason doesn't.
  --return perform_stash({ worktree = true, index = true })
end

function M.stash_index()
  return perform_stash { worktree = false, index = true }
end

function M.push(args, files)
  git.cli.stash.push.arg_list(args).files(unpack(files)).call()
end

function M.pop(stash)
  local result = git.cli.stash.apply.index.args(stash).show_popup(false).call()

  if result.code == 0 then
    git.cli.stash.drop.args(stash).call()
  else
    git.cli.stash.apply.args(stash).call()
  end
end

function M.apply(stash)
  local result = git.cli.stash.apply.index.args(stash).show_popup(false).call()

  if result.code ~= 0 then
    git.cli.stash.apply.args(stash).call()
  end
end

function M.drop(stash)
  git.cli.stash.drop.args(stash).call()
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
---@field idx number
---@field name string
---@field message string

function M.register(meta)
  meta.update_stashes = function(state)
    state.stashes.items = util.map(M.list(), function(line)
      local idx, message = line:match("stash@{(%d*)}: (.*)")

      return {
        idx = tonumber(idx),
        name = line,
        message = message,
      }
    end)
  end
end

return M
