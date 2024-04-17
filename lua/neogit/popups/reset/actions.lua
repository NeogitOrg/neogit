local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

---@param popup PopupData
---@return string|nil
local function commit(popup, prompt)
  local commit
  if popup.state.env.commit then
    commit = popup.state.env.commit
  else
    local commits = util.merge(git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())
    commit = FuzzyFinderBuffer.new(commits):open_async { prompt_prefix = prompt }
    if not commit then
      return
    end
  end

  if git.config.get("neogit.resetThisTo"):read() then
    commit = commit .. "^"
  end

  return commit
end

local function reset(type, popup, prompt)
  local target = commit(popup, prompt)
  if target then
    git.reset[type](target)
  end
end

function M.mixed(popup)
  reset("mixed", popup, ("Reset %s to"):format(git.branch.current()))
end

function M.soft(popup)
  reset("soft", popup, ("Soft reset %s to"):format(git.branch.current()))
end

function M.hard(popup)
  reset("hard", popup, ("Hard reset %s to"):format(git.branch.current()))
end

function M.keep(popup)
  reset("keep", popup, ("Reset %s to"):format(git.branch.current()))
end

function M.index(popup)
  reset("index", popup, "Reset index to")
end

function M.worktree(popup)
  local target = commit(popup, "Reset worktree to")
  if target then
    git.index.with_temp_index(target, function(index)
      git.cli["checkout-index"].all.force.env({ GIT_INDEX_FILE = index }).call()
      notification.info(("Reset worktree to %s"):format(target))
    end)
  end
end

function M.a_file(popup)
  local target = commit(popup, "Checkout from revision")
  if not target then
    return
  end

  local files = util.deduplicate(util.merge(git.files.all(), git.files.diff(target)))
  if not files[1] then
    notification.info(("No files differ between HEAD and %s"):format(target))
    return
  end

  local files = FuzzyFinderBuffer.new(files):open_async { allow_multi = true }
  if not files[1] then
    return
  end

  git.reset.file(target, files)
end

return M
