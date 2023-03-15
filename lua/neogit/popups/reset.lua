local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local status = require("neogit.status")

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local FileSelectViewBuffer = require("neogit.buffers.file_select_view")

local a = require("plenary.async")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitResetPopup")
    :group_heading("Reset")
    :action(
      "m",
      "mixed    (HEAD and index)",
      a.void(function()
        local commit = CommitSelectViewBuffer.new(git.log.list()):open_async()
        if not commit then
          return
        end

        git.reset.mixed(commit.oid)
        a.util.scheduler()
        status.refresh(true, "reset_mixed")
      end)
    )
    :action(
      "s",
      "soft     (HEAD only)",
      a.void(function()
        local commit = CommitSelectViewBuffer.new(git.log.list()):open_async()
        if not commit then
          return
        end

        git.reset.soft(commit.oid)
        a.util.scheduler()
        status.refresh(true, "reset_soft")
      end)
    )
    :action(
      "h",
      "hard     (HEAD, index and files)",
      a.void(function()
        local commit = CommitSelectViewBuffer.new(git.log.list()):open_async()
        if not commit then
          return
        end

        git.reset.hard(commit.oid)
        a.util.scheduler()
        status.refresh(true, "reset_hard")
      end)
    )
    :action(
      "k",
      "keep     (HEAD and index, keeping uncommitted)",
      a.void(function()
        local commit = CommitSelectViewBuffer.new(git.log.list()):open_async()
        if not commit then
          return
        end

        git.reset.keep(commit.oid)
        a.util.scheduler()
        status.refresh(true, "reset_keep")
      end)
    )
    :action("i", "index    (only)", false) -- https://github.com/magit/magit/blob/main/lisp/magit-reset.el#L78
    :action("w", "worktree (only)", false) -- https://github.com/magit/magit/blob/main/lisp/magit-reset.el#L87
    :group_heading("")
    :action(
      "f",
      "a file",
      a.void(function()
        local commit = CommitSelectViewBuffer.new(git.log.list()):open_async()
        if not commit then
          return
        end

        local files =
          git.cli["ls-files"].full_name.deleted.modified.exclude_standard.deduplicate.call_sync():trim().stdout
        local diff = git.cli.diff.name_only.args(commit.oid .. "...").call_sync():trim().stdout
        local all_files = util.deduplicate { unpack(files), unpack(diff) }
        if not all_files[1] then
          return
        end

        FileSelectViewBuffer.new(all_files, function(filepath)
          if filepath == "" then
            return
          end

          git.reset.file(commit.oid, filepath)
          status.dispatch_refresh(true)
        end):open()
      end)
    )
    :build()

  p:show()

  return p
end

return M
