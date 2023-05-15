local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local status = require("neogit.status")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local a = require("plenary.async")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitResetPopup")
    :group_heading("Reset")
    :action("m", "mixed    (HEAD and index)", function()
      local commit = CommitSelectViewBuffer.new(git.log.list({ "--max-count=256" })):open_async()
      if not commit then
        return
      end

      git.reset.mixed(commit)
      a.util.scheduler()
      status.refresh(true, "reset_mixed")
    end)
    :action("s", "soft     (HEAD only)", function()
      local commit = CommitSelectViewBuffer.new(git.log.list({ "--max-count=256" })):open_async()
      if not commit then
        return
      end

      git.reset.soft(commit)
      a.util.scheduler()
      status.refresh(true, "reset_soft")
    end)
    :action("h", "hard     (HEAD, index and files)", function()
      local commit = CommitSelectViewBuffer.new(git.log.list({ "--max-count=256" })):open_async()
      if not commit then
        return
      end

      git.reset.hard(commit)
      a.util.scheduler()
      status.refresh(true, "reset_hard")
    end)
    :action("k", "keep     (HEAD and index, keeping uncommitted)", function()
      local commit = CommitSelectViewBuffer.new(git.log.list({ "--max-count=256" })):open_async()
      if not commit then
        return
      end

      git.reset.keep(commit)
      a.util.scheduler()
      status.refresh(true, "reset_keep")
    end)
    :action("i", "index    (only)", function()
      local commit = CommitSelectViewBuffer.new(git.log.list({ "--max-count=256" })):open_async()
      if not commit then
        return
      end

      git.reset.index(commit)
      a.util.scheduler()
      status.refresh(true, "reset_index")
    end)
    :action("w", "worktree (only)", false) -- https://github.com/magit/magit/blob/main/lisp/magit-reset.el#L87
    :group_heading("")
    :action("f", "a file", function()
      local commit = CommitSelectViewBuffer.new(git.log.list(util.merge({ "--max-count=256", "--all" }, git.stash.list())))
        :open_async()
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
    end)
    :build()

  p:show()

  return p
end

return M
