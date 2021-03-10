local cli = require('neogit.lib.git.cli')
local a = require('neogit.async')

local function parse(output)
  local result = {}
  for _, line in ipairs(output) do
    local stash_num, stash_desc = line:match('stash@{(%d*)}: (.*)')
    table.insert(result, { idx = tonumber(stash_num), name = stash_desc})
  end
  return result
end

local function trim_null_terminator(str)
  return string.gsub(str, "^(.-)%z*$", "%1")
end

local perform_stash = a.sync(function (include)
  if not include then return end

  local index = a.wait(
    cli['commit-tree']
      .no_gpg_sign
      .parent('HEAD')
      .tree(a.wait(cli['write-tree'].call()))
      .call())

  a.wait(
    cli['read-tree']
      .merge
      .index_output('.git/NEOGIT_TMP_INDEX')
      .args(index)
      .call())

  if include.worktree then
    local files = a.wait(
      cli.diff
        .name_only
        .null_terminated
        .args('HEAD')
        .env({
          GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
        })
        .call())
    files = vim.split(trim_null_terminator(files), '\0')

    a.wait(
      cli['update-index']
        .add
        .remove
        .files(unpack(files))
        .env({
          GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
        })
        .call())
  end

  local tree = a.wait(
    cli['commit-tree']
      .no_gpg_sign
      .parents('HEAD', index)
      .tree(a.wait(cli['write-tree'].call()))
      .env({
        GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
      })
      .call())

  a.wait(
    cli['update-ref']
      .create_reflog
      .args('refs/stash', tree)
      .call())

  if include.worktree and include.index then
    -- disabled because stashing both worktree and index via this function
    -- leaves a malformed stash entry, so reverting the changes is
    -- destructive until fixed.
    --a.wait(
      --cli.reset
        --.hard
        --.commit('HEAD')
        --.call())
  elseif include.index then
    local diff = a.wait(
      cli.diff
        .cached
        .call()) .. '\n'

    a.wait(
      cli.apply
        .reverse
        .cached
        .input(diff)
        .call())
    a.wait(
      cli.apply
        .reverse
        .input(diff)
        .call())
  end
end)

return {
  parse = parse,
  stash_all = a.sync(function ()
    a.wait(cli.stash.call())
    -- this should work, but for some reason doesn't.
    --return perform_stash({ worktree = true, index = true })
  end),
  stash_index = function ()
    return perform_stash({ worktree = false, index = true })
  end,

  pop = a.sync(function (stash)
    local _, code = a.wait(cli.stash
      .apply
      .index
      .args(stash)
      .show_popup(false)
      .call())

    if code == 0 then
      a.wait(cli.stash
        .drop
        .args(stash)
        .call())
    else
      a.wait(cli.stash
        .apply
        .args(stash)
        .call())
    end
  end),

  apply = a.sync(function (stash)
    local _, code = a.wait(cli.stash
      .apply
      .index
      .args(stash)
      .show_popup(false)
      .call())

    if code ~= 0 then
      a.wait(cli.stash
        .apply
        .args(stash)
        .call())
    end
  end),

  drop = a.sync(function (stash)
    a.wait(cli.stash
      .drop
      .args(stash)
      .call())
  end)

}
