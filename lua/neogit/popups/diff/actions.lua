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
  local current = git.branch.current()

  local common_ranges = {}
  if current then
    local branches_to_compare = {}

    local base_branch = git.branch.base_branch()
    local have_base_branch = base_branch ~= nil and base_branch ~= ""
    if have_base_branch then
      table.insert(branches_to_compare, base_branch)
    end

    local upstream = git.branch.upstream("HEAD")
    if upstream ~= nil and upstream ~= "" then
      table.insert(branches_to_compare, upstream)
    end

    branches_to_compare = util.deduplicate(branches_to_compare)
    util.remove_item_from_table(branches_to_compare, current)

    for _, branch in pairs(branches_to_compare) do
      table.insert(common_ranges, branch .. "...HEAD")
      table.insert(common_ranges, branch .. "..HEAD")
    end

    if not have_base_branch then
      table.insert(common_ranges, "(neogit.baseBranch not set)")
    end
  end

  local options = util.deduplicate(util.merge({ "(select first)", "(custom range)" }, common_ranges))

  local range = nil
  local selection = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Diff" }
  if not selection then
    return
  end

  if selection == "(select first)" then
    local options = util.deduplicate(
      util.merge(
        { git.branch.current() or "HEAD" },
        git.branch.get_all_branches(false),
        git.tag.list(),
        git.refs.heads()
      )
    )

    local first_ref = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Diff" }
    if not first_ref then
      return
    end

    local second_ref = FuzzyFinderBuffer.new(options)
      :open_async { prompt_prefix = 'Diff from "' .. first_ref .. '" to ' }
    if not first_ref then
      return
    end

    options = { first_ref .. "..." .. second_ref, first_ref .. ".." .. second_ref }
    local selected_range = FuzzyFinderBuffer.new(options):open_async {
      prompt_prefix = 'Diff from merge-base or from "' .. first_ref .. '"?',
    }
    if not selected_range then
      return
    else
      range = selected_range
    end
  elseif selection == "(custom range)" then
    range = input.get_user_input("Diff for range", { strip_spaces = true })
  elseif selection == "(neogit.baseBranch not set)" then
    return
  else
    range = selection
  end

  popup:close()
  diffview.open("range", range)
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

  local options =
    util.merge(git.branch.get_all_branches(), git.tag.list(), { "HEAD", "ORIG_HEAD", "FETCH_HEAD" })

  local selected = FuzzyFinderBuffer.new(options):open_async()
  if selected then
    diffview.open("commit", selected)
  end
end

return M
