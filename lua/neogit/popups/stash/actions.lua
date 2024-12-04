local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local StashListBuffer = require("neogit.buffers.stash_list_view")

local M = {}

function M.both(popup)
  git.stash.stash_all(popup:get_arguments())
end

function M.index()
  git.stash.stash_index()
end

function M.keep_index()
  git.stash.stash_keep_index()
end

function M.push(popup)
  local files = FuzzyFinderBuffer.new(git.files.all()):open_async { allow_multi = true }
  if not files or not files[1] then
    return
  end

  git.stash.push(popup:get_arguments(), files)
end

local function use(action, stash, opts)
  opts = opts or {}
  local name, get_permission

  if stash and stash.name then
    get_permission = true
    name = stash.name
  else
    name = FuzzyFinderBuffer.new(git.stash.list()):open_async()
    if not name then
      return
    end

    name = name:match("(stash@{%d+})")
  end

  if name then
    if
      get_permission
      and opts.confirm
      and not input.get_permission(("%s%s '%s'?"):format(action:upper():sub(1, 1), action:sub(2, -1), name))
    then
      return
    end

    git.stash[action](name)
  end
end

function M.pop(popup)
  use("pop", popup.state.env.stash)
end

function M.apply(popup)
  use("apply", popup.state.env.stash)
end

function M.drop(popup)
  use("drop", popup.state.env.stash, { confirm = true })
end

function M.rename(popup)
  use("rename", popup.state.env.stash)
end

function M.list()
  StashListBuffer.new(git.repo.state.stashes.items):open()
end

return M
