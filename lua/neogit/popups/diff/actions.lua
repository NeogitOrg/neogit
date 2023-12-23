local M = {}
local diffview = require("neogit.integrations.diffview")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")

-- aka "dwim" = do what I mean
function M.this(popup)
  popup:close()

  if popup.state.env.section and popup.state.env.item then
    diffview.open(popup.state.env.section.name, popup.state.env.item.name, {
      only = true,
    })
  elseif popup.state.env.section then
    diffview.open(popup.state.env.section.name, nil, { only = true })
  end
end

function M.worktree(popup)
  popup:close()
  diffview.open()
end

function M.staged(popup)
  popup:close()
  diffview.open("staged", nil, { only = true })
end

function M.unstaged(popup)
  popup:close()
  diffview.open("unstaged", nil, { only = true })
end

function M.stash(popup)
  popup:close()

  local selected = FuzzyFinderBuffer.new(git.stash.list()):open_async()
  if selected then
    diffview.open("stashes", selected)
  end
end

function M.commit(popup)
  popup:close()

  local options = util.merge(
    git.branch.get_all_branches(),
    git.tag.list(),
    { "HEAD", "ORIG_HEAD", "FETCH_HEAD" }
  )

  local selected = FuzzyFinderBuffer.new(options):open_async()
  if selected then
    diffview.open("commit", selected)
  end
end

return M
