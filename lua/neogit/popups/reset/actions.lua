local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

---@param popup PopupData
---@param prompt string
---@return string|nil
local function target(popup, prompt)
  local commit = {}
  if popup.state.env.commit then
    commit = { popup.state.env.commit }
  end

  local refs = util.merge(commit, git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())
  return FuzzyFinderBuffer.new(refs):open_async { prompt_prefix = prompt }
end

---@param type string
---@param popup PopupData
---@param prompt string
local function reset(type, popup, prompt)
  local target = target(popup, prompt)
  if target then
    git.reset[type](target)
  end
end

---@param popup PopupData
function M.mixed(popup)
  reset("mixed", popup, ("Reset %s to"):format(git.branch.current()))
end

---@param popup PopupData
function M.soft(popup)
  reset("soft", popup, ("Soft reset %s to"):format(git.branch.current()))
end

---@param popup PopupData
function M.hard(popup)
  reset("hard", popup, ("Hard reset %s to"):format(git.branch.current()))
end

---@param popup PopupData
function M.keep(popup)
  reset("keep", popup, ("Reset %s to"):format(git.branch.current()))
end

---@param popup PopupData
function M.index(popup)
  reset("index", popup, "Reset index to")
end

---@param popup PopupData
function M.worktree(popup)
  local target = target(popup, "Reset worktree to")
  if target then
    git.index.with_temp_index(target, function(index)
      git.cli["checkout-index"].all.force.env({ GIT_INDEX_FILE = index }).call()
      notification.info(("Reset worktree to %s"):format(target))
    end)
  end
end

---@param popup PopupData
function M.a_file(popup)
  local target = target(popup, "Checkout from revision")
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
