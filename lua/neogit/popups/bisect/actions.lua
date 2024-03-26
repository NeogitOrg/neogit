local M = {}
local git = require("neogit.lib.git")
local notification = require("neogit.lib.notification")
local input = require("neogit.lib.input")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local util = require("neogit.lib.util")

function M.start(popup)
  if git.status.is_dirty() then
    notification.warn("Cannot bisect with uncommitted changes")
    return
  end

  popup.state.env.commits = popup.state.env.commits or {}

  local bad_revision, good_revision
  if popup.state.env.commits and #popup.state.env.commits > 1 then
    bad_revision = popup.state.env.commits[1]
    good_revision = popup.state.env.commits[#popup.state.env.commits]
  else
    local refs = util.merge(
      { popup.state.env.commits[1] },
      git.refs.list_branches(),
      git.refs.list_tags(),
      git.refs.heads()
    )
    bad_revision = FuzzyFinderBuffer.new(refs):open_async {
      prompt_prefix = "Start bisect with bad revision",
    }

    if not bad_revision then
      return
    end

    good_revision = FuzzyFinderBuffer.new(refs):open_async {
      prompt_prefix = "Good revision",
    }

    if not good_revision then
      return
    end
  end

  if git.log.is_ancestor(bad_revision, good_revision) then
    notification.info("Bisecting...")
    git.bisect.start(bad_revision, good_revision, popup:get_arguments())
  else
    local message = ("The good revision (%s) has to be an ancestor of the bad one (%s)"):format(
      good_revision,
      bad_revision
    )

    notification.warn(message)
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

function M.reset()
  git.bisect.reset()
end

function M.scripted()
  local command = input.get_user_input("Bisect shell command")
  if command then
    git.bisect.run(command)
  end
end

function M.run_script()
  print("run_script")
end

return M
