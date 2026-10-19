local M = {}
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

---@param popup any
---@return table
local function get_commits(popup)
  local commits
  if #popup.state.env.commits > 0 then
    commits = popup.state.env.commits
  else
    commits = CommitSelectViewBuffer.new(
      git.log.list { "--max-count=256" },
      git.remote.list(),
      "Select one or more commits to cherry pick with <cr>, or <esc> to abort"
    ):open_async()
  end

  return commits or {}
end

function M.pick(popup)
  local commits = get_commits(popup)
  if #commits == 0 then
    return
  end

  git.cherry_pick.pick(commits, popup:get_arguments())
end

function M.apply(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  git.cherry_pick.apply(commits, popup:get_arguments())
end

function M.squash(popup)
  local refs = util.merge(popup.state.env.commits, git.refs.list_branches(), git.refs.list_tags())
  local ref = FuzzyFinderBuffer.new(refs):open_async { prompt_prefix = "Squash" }
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--squash")
    git.merge.merge(ref, args)
  end
end

---@param popup PopupData
---@param verb string
---@return string[]
local function get_cherries(popup, verb)
  local commits
  if #popup.state.env.commits > 1 then
    commits = popup.state.env.commits
  else
    local refs = util.merge(popup.state.env.commits, git.refs.list_branches())
    local ref = FuzzyFinderBuffer.new(refs):open_async { prompt_prefix = verb .. " cherry" }

    if ref == popup.state.env.commits[1] then
      commits = popup.state.env.commits
    else
      commits = util.map(git.cherry.list(git.rev_parse.oid("HEAD"), ref), function(cherry)
        return cherry.oid or cherry
      end)
    end

    if not commits[1] then
      commits = { git.rev_parse.oid(ref) }
    end
  end

  return commits
end

---@param popup PopupData
function M.donate(popup)
  local commits = get_cherries(popup, "Donate")
  local src = git.branch.current() or git.rev_parse.oid("HEAD")

  if not git.log.is_ancestor(commits[1], git.rev_parse.oid(src)) then
    return notification.error("Cannot donate cherries that are not reachable from HEAD")
  end

  local prefix = string.format("Move %d cherr%s to branch", #commits, #commits > 1 and "ies" or "y")
  local options = git.refs.list_branches()
  util.remove_item_from_table(options, src)

  local dst = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = prefix }
  if dst then
    notification.info(
      ("Moved %d cherr%s from %q to %q"):format(#commits, #commits > 1 and "ies" or "y", src, dst)
    )
    git.cherry_pick.move(commits, src, dst, popup:get_arguments())
  end
end

---@param popup PopupData
function M.harvest(popup)
  local current = git.branch.current()
  if not current then
    return
  end

  local commits = get_cherries(popup, "Harvest")

  if git.log.is_ancestor(commits[1], git.rev_parse.oid("HEAD")) then
    return notification.error("Cannot harvest cherries that are reachable from HEAD")
  end

  local branch
  local containing_branches = git.branch.list_containing_branches(commits[1])
  if #containing_branches > 1 then
    local prefix = string.format("Remove %d cherr%s from branch", #commits, #commits > 1 and "ies" or "y")
    branch = FuzzyFinderBuffer.new(containing_branches):open_async { prompt_prefix = prefix }
  else
    branch = containing_branches[1]
  end

  if branch then
    notification.info(("Harvested %d cherr%s"):format(#commits, #commits > 1 and "ies" or "y"))
    git.cherry_pick.move(commits, branch, current, popup:get_arguments(), nil, true)
  end
end

---@param popup PopupData
---@param checkout boolean Whether to checkout the new branch afterwards (spinoff) or stay on current (spinout)
local function spin(popup, checkout)
  local commits = get_commits(popup)
  if #commits == 0 then
    return
  end

  local src = git.branch.current()
  if not src then
    return notification.error("Cannot spin out/off: not on a branch")
  end

  local prompt = checkout and "Spin-off to branch" or "Spin-out to branch"
  local name = input.get_user_input(prompt, { strip_spaces = true })
  if not name then
    return
  end

  if git.branch.exists(name) then
    return notification.error("Branch '" .. name .. "' already exists")
  end

  -- git.log.list returns newest-first; move() expects oldest-first so that
  -- tip = commits[#commits] is HEAD and keep = commits[1]^  is the reset point.
  local ordered = util.reverse(commits)
  -- Create the new branch at the parent of the oldest selected commit so the
  -- cherry-pick onto it is a clean fast-forward.
  local start = ordered[1] .. "^"

  git.cherry_pick.move(ordered, src, name, popup:get_arguments(), start, checkout)
end

---@param popup PopupData
function M.spinout(popup)
  spin(popup, false)
end

---@param popup PopupData
function M.spinoff(popup)
  spin(popup, true)
end

function M.continue()
  git.cherry_pick.continue()
end

function M.skip()
  git.cherry_pick.skip()
end

function M.abort()
  git.cherry_pick.abort()
end

return M
