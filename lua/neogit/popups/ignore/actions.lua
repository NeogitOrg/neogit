local git = require("neogit.lib.git")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

function M.both(popup)
  git.stash.stash_all(popup:get_arguments())
end

function M.index(popup)
  git.stash.stash_index(popup:get_arguments())
end

function M.push(popup)
  local files = FuzzyFinderBuffer.new(git.files.all()):open_async { allow_multi = true }
  if not files or not files[1] then
    return
  end

  git.stash.push(popup:get_arguments(), files)
end

local function use(action, stash)
  local name

  if stash and stash.name then
    name = stash.name
  else
    name = FuzzyFinderBuffer.new(git.stash.list()):open_async()
    if not name then
      return
    end

    name = name:match("(stash@{%d+})")
  end

  if name then
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
  use("drop", popup.state.env.stash)
end

return M
