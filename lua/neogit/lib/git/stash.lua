local cli = require('neogit.lib.git.cli')
local a = require('plenary.async_lib')
local async, await = a.async, a.await
local util = require('neogit.lib.util')

local function parse(output)
  local result = {}
  for _, line in ipairs(output) do
    local stash_num, stash_desc = line:match('stash@{(%d*)}: (.*)')
    table.insert(result, { idx = tonumber(stash_num), name = line, message = stash_desc})
  end
  return result
end

local function trim_null_terminator(str)
  return string.gsub(str, "^(.-)%z*$", "%1")
end

local perform_stash = async(function (include)
  if not include then return end

  local index = await(
    cli['commit-tree']
      .no_gpg_sign
      .parent('HEAD')
      .tree(await(cli['write-tree'].call()))
      .call())

  await(
    cli['read-tree']
      .merge
      .index_output('.git/NEOGIT_TMP_INDEX')
      .args(index)
      .call())

  if include.worktree then
    local files = await(
      cli.diff
        .name_only
        .null_terminated
        .args('HEAD')
        .env({
          GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
        })
        .call())
    files = vim.split(trim_null_terminator(files), '\0')

    await(
      cli['update-index']
        .add
        .remove
        .files(unpack(files))
        .env({
          GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
        })
        .call())
  end

  local tree = await(
    cli['commit-tree']
      .no_gpg_sign
      .parents('HEAD', index)
      .tree(await(cli['write-tree'].call()))
      .env({
        GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
      })
      .call())

  await(
    cli['update-ref']
      .create_reflog
      .args('refs/stash', tree)
      .call())

  if include.worktree and include.index then
    -- disabled because stashing both worktree and index via this function
    -- leaves a malformed stash entry, so reverting the changes is
    -- destructive until fixed.
    --await(
      --cli.reset
        --.hard
        --.commit('HEAD')
        --.call())
  elseif include.index then
    local diff = await(
      cli.diff
        .cached
        .call()) .. '\n'

    await(
      cli.apply
        .reverse
        .cached
        .input(diff)
        .call())
    await(
      cli.apply
        .reverse
        .input(diff)
        .call())
  end
end)

local update_stashes = a.sync(function (state)
  local result = a.wait(cli.stash.args('list').call())
  state.stashes.files = parse(util.split(result, '\n'))
end)

return {
  parse = parse,
  stash_all = async(function ()
    await(cli.stash.call())
    -- this should work, but for some reason doesn't.
    --return perform_stash({ worktree = true, index = true })
  end),
  stash_index = function ()
    return perform_stash({ worktree = false, index = true })
  end,

  pop = async(function (stash)
    local _, code = await(cli.stash
      .apply
      .index
      .args(stash)
      .show_popup(false)
      .call())

    if code == 0 then
      await(cli.stash
        .drop
        .args(stash)
        .call())
    else
      await(cli.stash
        .apply
        .args(stash)
        .call())
    end
  end),

  apply = async(function (stash)
    local _, code = await(cli.stash
      .apply
      .index
      .args(stash)
      .show_popup(false)
      .call())

    if code ~= 0 then
      await(cli.stash
        .apply
        .args(stash)
        .call())
    end
  end),

  drop = async(function (stash)
    await(cli.stash
      .drop
      .args(stash)
      .call())
  end),

  register = function (meta)
    meta.update_stashes = update_stashes
  end

}
