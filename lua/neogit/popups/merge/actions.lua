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
  if input.get_permission("Abort merge?") then
    git.merge.abort()
  end
end

function M.merge(popup)
  local branch = FuzzyFinderBuffer.new(git.refs.list_branches()):open_async()
  if branch then
    git.merge.merge(branch, popup:get_arguments())
  end
end

return M
