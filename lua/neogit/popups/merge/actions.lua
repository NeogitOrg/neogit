local M = {}

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

local a = require("plenary.async")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

function M.in_merge()
  local status = require("neogit.status")
  return status and status.repo.merge.head
end

function M.commit()
  git.merge.continue()
  a.util.scheduler()
  require("neogit.status").refresh(true, "merge_continue")
end

function M.abort()
  if not input.get_confirmation("Abort merge?", { values = { "&Yes", "&No" }, default = 2 }) then
    return
  end

  git.merge.abort()
  a.util.scheduler()
  require("neogit.status").refresh(true, "merge_abort")
end

function M.merge(popup)
  local branch = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_sync()
  if not branch then
    return
  end

  git.merge.merge(branch, popup:get_arguments())
  a.util.scheduler()
  require("neogit.status").refresh(true, "merge")
end

return M
