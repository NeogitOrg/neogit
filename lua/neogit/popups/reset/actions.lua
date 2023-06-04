local a = require("plenary.async")
local git = require("neogit.lib.git")
local status = require("neogit.status")
local util = require("neogit.lib.util")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

function M.mixed()
  local commit = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
  if not commit then
    return
  end

  git.reset.mixed(commit)
  a.util.scheduler()
  status.refresh(true, "reset_mixed")
end

function M.soft()
  local commit = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
  if not commit then
    return
  end

  git.reset.soft(commit)
  a.util.scheduler()
  status.refresh(true, "reset_soft")
end

function M.hard()
  local commit = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
  if not commit then
    return
  end

  git.reset.hard(commit)
  a.util.scheduler()
  status.refresh(true, "reset_hard")
end

function M.keep()
  local commit = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
  if not commit then
    return
  end

  git.reset.keep(commit)
  a.util.scheduler()
  status.refresh(true, "reset_keep")
end

function M.index()
  local commit = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
  if not commit then
    return
  end

  git.reset.index(commit)
  a.util.scheduler()
  status.refresh(true, "reset_index")
end

-- https://github.com/magit/magit/blob/main/lisp/magit-reset.el#L87
-- function M.worktree()
-- end

function M.a_file()
  local commits = git.log.list(util.merge({ "--max-count=256", "--all" }, git.stash.list()))

  local commit = CommitSelectViewBuffer.new(commits):open_async()
  if not commit then
    return
  end

  local files =
    git.cli["ls-files"].full_name.deleted.modified.exclude_standard.deduplicate.call_sync():trim().stdout
  local diff = git.cli.diff.name_only.args(commit .. "...").call_sync():trim().stdout
  local all_files = util.deduplicate(util.merge(files, diff))
  if not all_files[1] then
    return
  end

  a.util.scheduler()
  local files = FuzzyFinderBuffer.new(all_files):open_sync { allow_multi = true }
  if not files[1] then
    return
  end

  git.reset.file(commit, files)
  a.util.scheduler()
  status.refresh(true)
end

return M
