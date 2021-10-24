local cli = require('neogit.lib.git.cli')

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

local function perform_stash(include)
  if not include then return end

  local index = 
    cli['commit-tree']
      .no_gpg_sign
      .parent('HEAD')
      .tree(cli['write-tree'].call())
      .call()

  
    cli['read-tree']
      .merge
      .index_output('.git/NEOGIT_TMP_INDEX')
      .args(index)
      .call()

  if include.worktree then
    local files = 
      cli.diff
        .name_only
        .null_terminated
        .args('HEAD')
        .env({
          GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
        })
        .call()
    files = vim.split(trim_null_terminator(files), '\0')

    
      cli['update-index']
        .add
        .remove
        .files(unpack(files))
        .env({
          GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
        })
        .call()
  end

  local tree = 
    cli['commit-tree']
      .no_gpg_sign
      .parents('HEAD', index)
      .tree(cli['write-tree'].call())
      .env({
        GIT_INDEX_FILE = '.git/NEOGIT_TMP_INDEX'
      })
      .call()

  
    cli['update-ref']
      .create_reflog
      .args('refs/stash', tree)
      .call()

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
    local diff = 
      cli.diff
        .cached
        .call() .. '\n'

    
      cli.apply
        .reverse
        .cached
        .input(diff)
        .call()
    
      cli.apply
        .reverse
        .input(diff)
        .call()
  end
end

local function update_stashes(state)
  local result = cli.stash.args('list').call()
  state.stashes.items = parse(result)
end

return {
  parse = parse,
  stash_all = function ()
    cli.stash.call()
    -- this should work, but for some reason doesn't.
    --return perform_stash({ worktree = true, index = true })
  end,
  stash_index = function ()
    return perform_stash({ worktree = false, index = true })
  end,

  pop = function (stash)
    local _, code = cli.stash
      .apply
      .index
      .args(stash)
      .show_popup(false)
      .call()

    if code == 0 then
      cli.stash
        .drop
        .args(stash)
        .call()
    else
      cli.stash
        .apply
        .args(stash)
        .call()
    end
  end,

  apply = function (stash)
    local _, code = cli.stash
      .apply
      .index
      .args(stash)
      .show_popup(false)
      .call()

    if code ~= 0 then
      cli.stash
        .apply
        .args(stash)
        .call()
    end
  end,

  drop = function (stash)
    cli.stash
      .drop
      .args(stash)
      .call()
  end,

  register = function (meta)
    meta.update_stashes = update_stashes
  end
}
