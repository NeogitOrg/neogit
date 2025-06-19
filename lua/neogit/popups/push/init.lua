local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.push.actions")
local git = require("neogit.lib.git")

local M = {}

function M.create(env)
  local current = git.branch.current() or ""
  local is_detached = git.branch.is_detached()

  local p = popup
    .builder()
    :name("NeogitPushPopup")
    :switch("f", "force-with-lease", "Force with lease", { persisted = false })
    :switch("F", "force", "Force", { persisted = false })
    :switch("h", "no-verify", "Disable hooks")
    :switch("d", "dry-run", "Dry run")
    :switch("u", "set-upstream", "Set the upstream before pushing")
    :switch("T", "tags", "Include all tags")
    :switch("t", "follow-tags", "Include related annotated tags")
    :group_heading_if(not is_detached, "Push " .. current .. " to")
    :action_if(not is_detached, "p", git.branch.pushRemote_or_pushDefault_label(), actions.to_pushremote)
    :action_if(not is_detached, "u", git.branch.upstream_label(), actions.to_upstream)
    :action_if(not is_detached, "e", "elsewhere", actions.to_elsewhere)
    :group_heading_if(is_detached, "Push")
    :new_action_group_if(not is_detached, "Push")
    :action("o", "another branch", actions.push_other)
    :action("r", "explicit refspec", actions.explicit_refspec)
    :action("m", "matching branches", actions.matching_branches)
    :action("T", "a tag", actions.push_a_tag)
    :action("t", "all tags", actions.push_all_tags)
    :new_action_group("Configure")
    :action("C", "Set variables...", actions.configure)
    :env({
      highlight = {
        current,
        git.branch.upstream(),
        git.branch.pushRemote_ref(),
        git.branch.pushDefault_ref(),
      },
      bold = { "pushRemote", "@{upstream}" },
      commit = env.commit,
    })
    :build()

  p:show()

  return p
end

return M
