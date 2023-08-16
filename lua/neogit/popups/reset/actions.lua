local a = require("plenary.async")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function reset(type, popup)
  local commit
  if popup.state.env.commit then
    commit = popup.state.env.commit
  else
    commit = CommitSelectViewBuffer.new(git.log.list()):open_async()[1]
    if not commit then
      return
    end
  end

  git.reset[type](commit)
end

function M.mixed(popup)
  reset("mixed", popup)
end

function M.soft(popup)
  reset("soft", popup)
end

function M.hard(popup)
  reset("hard", popup)
end

function M.keep(popup)
  reset("keep", popup)
end

function M.index(popup)
  reset("index", popup)
end

-- https://github.com/magit/magit/blob/main/lisp/magit-reset.el#L87
-- function M.worktree()
-- end

function M.a_file(popup)
  local commit
  if popup.state.env.commit then
    commit = popup.state.env.commit
  else
    local commits = git.log.list(util.merge({ "--all" }, git.stash.list_refs()))
    commit = CommitSelectViewBuffer.new(commits):open_async()[1]
    if not commit then
      return
    end
  end

  local files = util.deduplicate(util.merge(git.files.all(), git.files.diff(commit)))
  if not files[1] then
    return
  end

  a.util.scheduler()
  local files = FuzzyFinderBuffer.new(files):open_async { allow_multi = true }
  if not files[1] then
    return
  end

  git.reset.file(commit, files)
end

return M
