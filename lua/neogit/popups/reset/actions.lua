local a = require("plenary.async")
local git = require("neogit.lib.git")
local status = require("neogit.status")
local util = require("neogit.lib.util")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function reset(type)
  local commit = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
  if not commit then
    return
  end

  git.reset[type](commit)
  a.util.scheduler()
  status.refresh(true, "reset_" .. type)
end

function M.mixed()
  reset("mixed")
end

function M.soft()
  reset("soft")
end

function M.hard()
  reset("hard")
end

function M.keep()
  reset("keep")
end

function M.index()
  reset("index")
end

-- https://github.com/magit/magit/blob/main/lisp/magit-reset.el#L87
-- function M.worktree()
-- end

function M.a_file()
  local commits = git.log.list(util.merge({ "--max-count=256", "--all" }, git.stash.list_refs()))

  local commit = CommitSelectViewBuffer.new(commits):open_async()
  if not commit then
    return
  end

  local files = util.deduplicate(util.merge(git.files.all(), git.files.diff(commit)))
  if not files[1] then
    return
  end

  a.util.scheduler()
  local files = FuzzyFinderBuffer.new(files):open_sync { allow_multi = true }
  if not files[1] then
    return
  end

  git.reset.file(commit, files)
  a.util.scheduler()
  status.refresh(true, "reset_file")
end

return M
