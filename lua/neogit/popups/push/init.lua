local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.push.actions")
local git = require("neogit.lib.git")

local M = {}

function M.create()
  local current = git.repo.head.branch

  local p = popup
    .builder()
    :name("NeogitPushPopup")
    :switch("f", "force-with-lease", "Force with lease")
    :switch("F", "force", "Force")
    :switch("u", "set-upstream", "Set the upstream before pushing")
    :switch("h", "no-verify", "Disable hooks")
    :switch("d", "dry-run", "Dry run")
    :group_heading("Push " .. ((current and (current .. " ")) or "") .. "to")
    :action("p", git.branch.pushRemote_label(), actions.to_pushremote)
    :action("u", git.branch.upstream_label(), actions.to_upstream)
    :action("e", "elsewhere", actions.to_elsewhere)
    :new_action_group("Push")
    :action("o", "another branch", actions.push_other)
    :action("r", "explicit refspecs")
    :action("m", "matching branches")
    :action("T", "a tag")
    :action("t", "all tags")
    :new_action_group("Configure")
    :action("C", "Set variables...", actions.configure)
    :env(
      {
        highlight = { current, git.repo.upstream.ref, git.branch.pushRemote_ref() },
        bold = { "pushRemote", "@{upstream}" }
      }
    )
    :build()

  p:show()

  return p
end

return M
