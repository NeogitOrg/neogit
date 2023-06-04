local a = require("plenary.async")
local status = require("neogit.status")
local git = require("neogit.lib.git")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

function M.both(popup)
  git.stash.stash_all(popup:get_arguments())
  a.util.scheduler()
  status.refresh(true, "stash_both")
end

function M.index(popup)
  git.stash.stash_index(popup:get_arguments())
  a.util.scheduler()
  status.refresh(true, "stash_index")
end

function M.push(popup)
  local files = FuzzyFinderBuffer.new(git.files.all()):open_sync { allow_multi = true }
  if not files or not files[1] then
    return
  end

  git.stash.push(popup:get_arguments(), files)
  a.util.scheduler()
  status.refresh(true, "stash_push")
end

function M.pop(popup)
  git.stash.pop(popup.state.env.stash.name)
  a.util.scheduler()
  status.refresh(true, "stash_pop")
end

function M.apply(popup)
  git.stash.apply(popup.state.env.stash.name)
  a.util.scheduler()
  status.refresh(true, "stash_apply")
end

function M.drop(popup)
  git.stash.drop(popup.state.env.stash.name)
  a.util.scheduler()
  status.refresh(true, "stash_drop")
end

return M
