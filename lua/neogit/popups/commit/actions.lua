local M = {}

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local git = require("neogit.lib.git")
local client = require("neogit.client")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")
local a = require("plenary.async")

local function confirm_modifications()
  if
    git.branch.upstream()
    and #git.repo.upstream.unmerged.items < 1
    and not input.get_confirmation(
      string.format(
        "This commit has already been published to %s, do you really want to modify it?",
        git.branch.upstream()
      ),
      { values = { "&Yes", "&No" }, default = 2 }
    )
  then
    return false
  end

  return true
end

local function do_commit(popup, cmd)
  client.wrap(cmd.arg_list(popup:get_arguments()), {
    autocmd = "NeogitCommitComplete",
    msg = {
      success = "Committed",
    },
  })
end

local function commit_special(popup, method, opts)
  if not git.status.anything_staged() then
    if git.status.anything_unstaged() then
      local stage_all = input.get_confirmation(
        "Nothing is staged. Commit all uncommitted changed?",
        { values = { "&Yes", "&No" }, default = 2 }
      )

      if stage_all then
        opts.all = true
      else
        return
      end
    else
      notification.warn("No changes to commit.")
      return
    end
  end

  local commit
  if popup.state.env.commit then
    commit = popup.state.env.commit
  else
    commit = CommitSelectViewBuffer.new(git.log.list()):open_async()[1]
    if not commit then
      return
    end
  end

  if opts.rebase and not git.log.is_ancestor(commit, "HEAD") then
    local msg = string.format("'%s' isn't an ancestor of HEAD.", string.sub(commit, 1, 7))
    local choice = input.get_choice(msg, {
      values = {
        "&create without rebasing",
        "&select other",
        "&abort",
      },
      default = 3,
    })

    if choice == "c" then
      opts.rebase = false
    elseif choice == "s" then
      commit = CommitSelectViewBuffer.new(git.log.list()):open_async()[1]
    else
      return
    end
  end

  local cmd = git.cli.commit.args(string.format("--%s=%s", method, commit))
  if opts.edit then
    cmd = cmd.edit
  else
    cmd = cmd.no_edit
  end

  if opts.all then
    cmd = cmd.all
  end

  a.util.scheduler()
  do_commit(popup, cmd)

  if opts.rebase then
    a.util.scheduler()
    git.rebase.rebase_interactive(commit .. "~1", { "--autosquash", "--autostash", "--keep-empty" })
  end
end

function M.commit(popup)
  do_commit(popup, git.cli.commit)
end

function M.extend(popup)
  if not confirm_modifications() then
    return
  end

  do_commit(popup, git.cli.commit.no_edit.amend)
end

function M.reword(popup)
  if not confirm_modifications() then
    return
  end

  do_commit(popup, git.cli.commit.amend.only)
end

function M.amend(popup)
  if not confirm_modifications() then
    return
  end

  do_commit(popup, git.cli.commit.amend)
end

function M.fixup(popup)
  commit_special(popup, "fixup", { edit = false })
end

function M.squash(popup)
  commit_special(popup, "squash", { edit = false })
end

function M.augment(popup)
  commit_special(popup, "squash", { edit = true })
end

function M.instant_fixup(popup)
  if not confirm_modifications() then
    return
  end

  commit_special(popup, "fixup", { rebase = true, edit = false })
end

function M.instant_squash(popup)
  if not confirm_modifications() then
    return
  end

  commit_special(popup, "squash", { rebase = true, edit = false })
end

return M
