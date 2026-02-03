local M = {}
local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")
local input = require("neogit.lib.input")
local operation = require("neogit.lib.operation")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local util = require("neogit.lib.util")

---@return table<string, string>|nil
local function use_popup_revisions(popup)
  local bad_revision = popup.state.env.commits[1]
  local good_revision = popup.state.env.commits[#popup.state.env.commits]

  if git.log.is_ancestor(good_revision, bad_revision) then
    return { bad_revision, good_revision }
  elseif git.log.is_ancestor(bad_revision, good_revision) then
    return { good_revision, bad_revision }
  else
    local message = ("The first revision selected (%s) has to be an ancestor of the last one (%s)"):format(
      bad_revision,
      good_revision
    )

    notification.warn(message)
  end
end

---@return table<string, string>|nil
local function get_user_revisions(popup)
  local refs =
    util.merge(popup.state.env.commits, git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())
  local bad_revision = FuzzyFinderBuffer.new(refs):open_async {
    prompt_prefix = "Start bisect with bad revision",
  }

  if not bad_revision then
    return
  end

  util.remove_item_from_table(refs, bad_revision)
  local good_revision = FuzzyFinderBuffer.new(refs):open_async {
    prompt_prefix = "Good revision",
  }

  if not good_revision then
    return
  end

  if git.log.is_ancestor(good_revision, bad_revision) then
    return { bad_revision, good_revision }
  else
    local message = ("The good revision (%s) has to be an ancestor of the bad one (%s)"):format(
      good_revision,
      bad_revision
    )

    notification.warn(message)
  end
end

---@param popup table
---@return table<string, string>|nil
local function revisions(popup)
  popup.state.env.commits = popup.state.env.commits or {}
  local revisions
  if #popup.state.env.commits > 1 then
    revisions = use_popup_revisions(popup)
  else
    revisions = get_user_revisions(popup)
  end

  if revisions then
    return revisions
  end
end

function M.start(popup)
  if git.status.is_dirty() then
    notification.warn("Cannot bisect with uncommitted changes")
    return
  end

  local revisions = revisions(popup)
  if revisions then
    notification.info("Bisecting...")
    local bad_revision, good_revision = unpack(revisions)
    git.bisect.start(bad_revision, good_revision, popup:get_arguments())
  end
end

function M.scripted(popup)
  if git.status.is_dirty() then
    notification.warn("Cannot bisect with uncommitted changes")
    return
  end

  local revisions = revisions(popup)
  if revisions then
    local command = input.get_user_input("Bisect shell command")
    if command then
      local bad_revision, good_revision = unpack(revisions)
      git.bisect.start(bad_revision, good_revision, popup:get_arguments())

      local op = operation.start("Bisecting with script")
      local result = git.bisect.run(command)
      if result and result:success() then
        operation.finish(op)
      else
        operation.fail(op, "Bisect script failed")
      end
    end
  end
end

function M.good()
  git.bisect.good()
end

function M.bad()
  git.bisect.bad()
end

function M.skip()
  git.bisect.skip()
end

function M.reset_with_permission()
  if input.get_permission("End bisection?") then
    git.bisect.reset()
  end
end

function M.reset()
  git.bisect.reset()
end

function M.run()
  local command = input.get_user_input("Bisect shell command")
  if command then
    local op = operation.start("Bisecting with script")
    local result = git.bisect.run(command)
    if result and result:success() then
      operation.finish(op)
    else
      operation.fail(op, "Bisect script failed")
    end
  end
end

return M
