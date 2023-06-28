local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

local function perform_stash(include)
  if not include then
    return
  end

  local index =
    cli["commit-tree"].no_gpg_sign.parent("HEAD").tree(cli["write-tree"].call().stdout).call().stdout

  cli["read-tree"].merge.index_output(".git/NEOGIT_TMP_INDEX").args(index).call()

  if include.worktree then
    local files = cli.diff.no_ext_diff.name_only
      .args("HEAD")
      .env({
        GIT_INDEX_FILE = ".git/NEOGIT_TMP_INDEX",
      })
      .call()
      :trim()

    cli["update-index"].add.remove
      .files(unpack(files))
      .env({
        GIT_INDEX_FILE = ".git/NEOGIT_TMP_INDEX",
      })
      .call()
  end

  local tree = cli["commit-tree"].no_gpg_sign
    .parents("HEAD", index)
    .tree(cli["write-tree"].call())
    .env({
      GIT_INDEX_FILE = ".git/NEOGIT_TMP_INDEX",
    })
    .call()

  cli["update-ref"].create_reflog.args("refs/stash", tree).call()

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
    local diff = cli.diff.no_ext_diff.cached.call():trim().stdout[1] .. "\n"

    cli.apply.reverse.cached.input(diff).call()

    cli.apply.reverse.input(diff).call()
  end
end

function M.list_refs()
  local result = cli.reflog.show.format("%h").args("stash").call_ignoring_exit_code():trim()
  if result.code > 0 then
    return {}
  else
    return result.stdout
  end
end

function M.stash_all(args)
  cli.stash.arg_list(args).call()
  -- this should work, but for some reason doesn't.
  --return perform_stash({ worktree = true, index = true })
end

function M.stash_index()
  return perform_stash { worktree = false, index = true }
end

function M.push(args, files)
  cli.stash.push.arg_list(args).files(unpack(files)).call()
end

function M.pop(stash)
  local result = cli.stash.apply.index.args(stash).show_popup(false).call()

  if result.code == 0 then
    cli.stash.drop.args(stash).call()
  else
    cli.stash.apply.args(stash).call()
  end
end

function M.apply(stash)
  local result = cli.stash.apply.index.args(stash).show_popup(false).call()

  if result.code ~= 0 then
    cli.stash.apply.args(stash).call()
  end
end

function M.drop(stash)
  cli.stash.drop.args(stash).call()
end

function M.list()
  return cli.stash.args("list").call():trim().stdout
end

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
