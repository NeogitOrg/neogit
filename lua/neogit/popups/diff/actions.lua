local M = {}
local diffview = require("neogit.integrations.diffview")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

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

function M.range(popup)
  local options = util.deduplicate(
    util.merge(
      { git.branch.current() or "HEAD" },
      git.branch.get_all_branches(false),
      git.tag.list(),
      git.refs.heads()
    )
  )

  local range_from = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Diff for range from" }
  if not range_from then
    return
  end

  local range_to = FuzzyFinderBuffer.new(options)
    :open_async { prompt_prefix = "Diff from " .. range_from .. " to" }
  if not range_to then
    return
  end

  local choices = {
    "&1. " .. range_from .. ".." .. range_to,
    "&2. " .. range_from .. "..." .. range_to,
    "&3. Cancel",
  }
  local choice = input.get_choice("Select range", { values = choices, default = #choices })

  popup:close()
  if choice == "1" then
    diffview.open("range", range_from .. ".." .. range_to)
  elseif choice == "2" then
    diffview.open("range", range_from .. "..." .. range_to)
  end
end

function M.worktree(popup)
  popup:close()
  diffview.open("worktree")
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

  local options = util.merge(git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())

  local selected = FuzzyFinderBuffer.new(options):open_async()
  if selected then
    diffview.open("commit", selected)
  end
end

return M
