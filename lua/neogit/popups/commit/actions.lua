local M = {}

local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")
local git = require("neogit.lib.git")
local client = require("neogit.client")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")
local config = require("neogit.config")
local a = require("plenary.async")

---@param popup PopupData
---@return boolean
local function allow_empty(popup)
  return vim.tbl_contains(popup:get_arguments(), "--allow-empty")
    or vim.tbl_contains(popup:get_arguments(), "--all")
end

local function confirm_modifications()
  if
    git.branch.upstream()
    and #git.repo.state.upstream.unmerged.items < 1
    and not input.get_permission(
      string.format(
        "This commit has already been published to %s, do you really want to modify it?",
        git.branch.upstream()
      )
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
    interactive = true,
    show_diff = config.values.commit_editor.show_staged_diff,
  })
end

local function commit_special(popup, method, opts)
  if not git.status.anything_staged() and not allow_empty(popup) then
    if git.status.anything_unstaged() then
      if input.get_permission("Nothing is staged. Commit all uncommitted changed?") then
        opts.all = true
      else
        return
      end
    else
      notification.warn("No changes to commit.")
      return
    end
  end

  local commit = popup.state.env.commit
    or CommitSelectViewBuffer.new(git.log.list(), git.remote.list()):open_async()[1]
  if not commit then
    return
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
      commit = CommitSelectViewBuffer.new(git.log.list(), git.remote.list()):open_async()[1]
    else
      return
    end
  end

  local cmd = git.cli.commit
  if opts.edit then
    cmd = cmd.edit
  else
    cmd = cmd.no_edit
  end

  if opts.all then
    cmd = cmd.all
  end

  a.util.scheduler()
  do_commit(popup, cmd.args(string.format("--%s=%s", method, commit)))

  if opts.rebase then
    a.util.scheduler()
    git.rebase.instantly(commit .. "~1", { "--keep-empty" })
  end
end

function M.commit(popup)
  if not git.status.anything_staged() and not allow_empty(popup) then
    notification.warn("No changes to commit.")
    return
  end

  do_commit(popup, git.cli.commit)
end

function M.extend(popup)
  if not git.status.anything_staged() and not allow_empty(popup) then
    if git.status.anything_unstaged() then
      if input.get_permission("Nothing is staged. Commit all uncommitted changes?") then
        git.status.stage_modified()
      else
        return
      end
    else
      return notification.warn("No changes to commit.")
    end
  end

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

function M.absorb(popup)
  if vim.fn.executable("git-absorb") == 0 then
    notification.info("Absorb requires `https://github.com/tummychow/git-absorb` to be installed.")
    return
  end

  if not git.status.anything_staged() and not allow_empty(popup) then
    if git.status.anything_unstaged() then
      if input.get_permission("Nothing is staged. Absorb all unstaged changes?") then
        git.status.stage_modified()
      else
        return
      end
    else
      notification.warn("There are no changes that could be absorbed")
      return
    end
  end

  local commit = popup.state.env.commit
    or CommitSelectViewBuffer.new(
      git.log.list { "HEAD" },
      git.remote.list(),
      "Select a base commit for the absorb stack with <cr>, or <esc> to abort"
    )
      :open_async()[1]
  if not commit then
    return
  end

  git.cli.absorb.verbose.base(commit .. "^").and_rebase.env({ GIT_SEQUENCE_EDITOR = ":" }).call()
end

return M
