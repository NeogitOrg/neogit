local actions = require("neogit.popups.pull.actions")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}

function M.create()
  local current_branch_name = git.branch.current()
  local is_on_a_branch = current_branch_name ~= nil

  local pull_rebase_entry = git.config.get("pull.rebase")
  local pull_rebase_value = pull_rebase_entry:is_set() and pull_rebase_entry.value or "false"

  local p_builder = popup.builder():name("NeogitPullPopup")

  if is_on_a_branch then
    p_builder:config("r", "branch." .. current_branch_name .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. pull_rebase_value, value = "" },
      },
    })
  end

  p_builder
    :switch("f", "ff-only", "Fast-forward only")
    :switch("r", "rebase", "Rebase local commits", { persisted = false })
    :switch("a", "autostash", "Autostash")
    :switch("t", "tags", "Fetch tags")
    :switch("F", "force", "Force", { persisted = false })

  if is_on_a_branch then
    p_builder
      :group_heading("Pull into " .. current_branch_name .. " from")
      :action("p", git.branch.pushRemote_label(), actions.from_pushremote)
      :action("u", git.branch.upstream_label(), actions.from_upstream)
      :action("e", "elsewhere", actions.from_elsewhere)
  else
    p_builder
      :group_heading("Pull from (Detached HEAD)")
      :action("p", "elsewhere (select remote/branch)", actions.from_elsewhere)
      :action("e", "elsewhere (select remote/branch)", actions.from_elsewhere)
  end

  p_builder:new_action_group("Configure"):action("C", "Set variables...", actions.configure)

  p_builder:env {
    highlight = { current_branch_name, git.branch.upstream(), git.branch.pushRemote_ref() },
    bold = { "pushRemote", "@{upstream}" },
  }

  local final_popup_obj = p_builder:build()
  final_popup_obj:show()
  return final_popup_obj
end

return M
