local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.rebase.actions")

local M = {}

function M.create(env)
  local branch = git.branch.current()
  local in_rebase = git.rebase.in_progress()
  local base_branch = git.branch.base_branch()
  local show_base_branch = branch ~= base_branch and base_branch ~= nil

  local p = popup
    .builder()
    :name("NeogitRebasePopup")
    :group_heading_if(in_rebase, "Actions")
    :action_if(in_rebase, "r", "Continue", actions.continue)
    :action_if(in_rebase, "s", "Skip", actions.skip)
    :action_if(in_rebase, "e", "Edit", actions.edit)
    :action_if(in_rebase, "a", "Abort", actions.abort)
    :switch_if(not in_rebase, "k", "keep-empty", "Keep empty commits")
    :option_if(not in_rebase, "r", "rebase-merges", "", "Rebase merges", {
      choices = { "no-rebase-cousins", "rebase-cousins" },
      key_prefix = "-",
    })
    :switch_if(not in_rebase, "u", "update-refs", "Update branches")
    :switch_if(not in_rebase, "d", "committer-date-is-author-date", "Use author date as committer date")
    :switch_if(not in_rebase, "t", "ignore-date", "Use current time as author date")
    :switch_if(not in_rebase, "a", "autosquash", "Autosquash")
    :switch_if(not in_rebase, "A", "autostash", "Autostash", { enabled = true })
    :switch_if(not in_rebase, "i", "interactive", "Interactive")
    :switch_if(not in_rebase, "h", "no-verify", "Disable hooks")
    :option_if(not in_rebase, "S", "gpg-sign", "", "Sign using gpg", { key_prefix = "-" })
    :group_heading_if(not in_rebase, "Rebase " .. (branch and (branch .. " ") or "") .. "onto")
    :action_if(not in_rebase, "p", git.branch.pushRemote_label(), actions.onto_pushRemote)
    :action_if(not in_rebase, "u", git.branch.upstream_label(), actions.onto_upstream)
    :action_if(not in_rebase, "e", "elsewhere", actions.onto_elsewhere)
    :action_if(not in_rebase and show_base_branch, "b", base_branch or "", actions.onto_base)
    :new_action_group_if(not in_rebase, "Rebase")
    :action_if(not in_rebase, "i", "interactively", actions.interactively)
    :action_if(not in_rebase, "s", "a subset", actions.subset)
    :new_action_group_if(not in_rebase)
    :action_if(not in_rebase, "m", "to modify a commit", actions.modify)
    :action_if(not in_rebase, "w", "to reword a commit", actions.reword)
    :action_if(not in_rebase, "d", "to remove a commit", actions.drop)
    :action_if(not in_rebase, "f", "to autosquash", actions.autosquash)
    :env({
      commit = env.commit,
      highlight = { branch, git.repo.state.upstream.ref, base_branch },
      bold = { "@{upstream}", "pushRemote" },
    })
    :build()

  p:show()

  return p
end

return M
