local M = {}

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

function M.in_merge()
  return git.repo.merge.head
end

function M.commit()
  git.merge.continue()
end

function M.abort()
  if not input.get_confirmation("Abort merge?", { values = { "&Yes", "&No" }, default = 2 }) then
    return
  end

  git.merge.abort()
end

function M.merge(popup)
  local branch = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_async()
  if not branch then
    return
  end

  git.merge.merge(branch, popup:get_arguments())
end

return M
