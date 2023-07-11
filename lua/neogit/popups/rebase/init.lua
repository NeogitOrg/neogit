local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.rebase.actions")

local M = {}

function M.create(commit)
  local branch = git.repo.head.branch
  local in_rebase = git.repo.rebase.head
  local base_branch = actions.base_branch()

  local p = popup
    .builder()
    :name("NeogitRebasePopup")
    :group_heading_if(in_rebase, "Actions")
    :action_if(in_rebase, "r", "Continue", actions.continue)
    :action_if(in_rebase, "s", "Skip", actions.skip)
    :action_if(in_rebase, "e", "Edit")
    :action_if(in_rebase, "a", "Abort", actions.abort)
    :switch_if(not in_rebase, "k", "keep-empty", "Keep empty commits")
    :switch_if(not in_rebase, "u", "update-refs", "Update branches")
    :switch_if(not in_rebase, "d", "committer-date-is-author-date", "Use author date as committer date")
    :switch_if(not in_rebase, "t", "ignore-date", "Use current time as author date")
    :switch_if(not in_rebase, "a", "autosquash", "Autosquash fixup and squash commits")
    :switch_if(not in_rebase, "A", "autostash", "Autostash", { enabled = true })
    :switch_if(not in_rebase, "i", "interactive", "Interactive")
    :switch_if(not in_rebase, "h", "no-verify", "Disable hooks")
    :option_if(not in_rebase, "s", "gpg-sign", "", "Sign using gpg")
    :option_if(not in_rebase, "r", "rebase-merges", "", "Rebase merges")
    :group_heading_if(not in_rebase, "Rebase " .. (branch and (branch .. " ") or "") .. "onto")
    :action_if(not in_rebase, "p", git.branch.pushRemote_label(), actions.onto_pushRemote)
    :action_if(not in_rebase, "u", git.branch.upstream_label(), actions.onto_upstream)
    :action_if(not in_rebase and branch ~= base_branch, "b", base_branch, actions.onto_base)
    :action_if(not in_rebase, "e", "elsewhere", actions.onto_elsewhere)
    :action_if(not in_rebase and branch ~= base_branch, "b", base_branch, actions.onto_base)
    :new_action_group_if(not in_rebase, "Rebase")
    :action_if(not in_rebase, "i", "interactively", actions.interactively)
    :action_if(not in_rebase, "s", "a subset")
    :new_action_group_if(not in_rebase)
    :action_if(not in_rebase, "m", "to modify a commit")
    :action_if(not in_rebase, "w", "to reword a commit")
    :action_if(not in_rebase, "k", "to remove a commit")
    :action_if(not in_rebase, "f", "to autosquash")
    :env({
      commit = commit,
      highlight = { branch, git.repo.upstream.ref },
      bold = { "@{upstream}", "pushRemote" },
    })
    :build()

  p:show()

  return p
end

return M
