local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local event = require("neogit.lib.event")

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

---@param fn fun(target: string): boolean
---@param popup PopupData
---@param prompt string
---@param mode string
local function reset(fn, popup, prompt, mode)
  local target = target(popup, prompt)
  if target then
    local success = fn(target)
    if success then
      notification.info("Reset to " .. target)
      event.send("Reset", { commit = target, mode = mode })
    else
      notification.error("Reset Failed")
    end
  end
end

---@param popup PopupData
function M.mixed(popup)
  reset(git.reset.mixed, popup, ("Reset %s to"):format(git.branch.current()), "mixed")
end

---@param popup PopupData
function M.soft(popup)
  reset(git.reset.soft, popup, ("Soft reset %s to"):format(git.branch.current()), "soft")
end

---@param popup PopupData
function M.hard(popup)
  reset(git.reset.hard, popup, ("Hard reset %s to"):format(git.branch.current()), "hard")
end

---@param popup PopupData
function M.keep(popup)
  reset(git.reset.keep, popup, ("Reset %s to"):format(git.branch.current()), "keep")
end

---@param popup PopupData
function M.index(popup)
  reset(git.reset.index, popup, "Reset index to", "index")
end

---@param popup PopupData
function M.worktree(popup)
  reset(git.reset.worktree, popup, "Reset worktree to", "worktree")
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

  local success = git.reset.file(target, files)
  if not success then
    notification.error("Reset Failed")
  else
    if #files > 1 then
      notification.info("Reset " .. #files .. " files")
    else
      notification.info("Reset " .. files[1])
    end

    event.send("Reset", { commit = target, mode = "files", files = files })
  end
end

return M
