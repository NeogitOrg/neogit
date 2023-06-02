local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.push.actions")
local git = require("neogit.lib.git")

local M = {}

local function pushRemote_description()
  local current = git.repo.head.branch
  local pushRemote = git.config.get("branch." .. current .. ".pushRemote").value

  if current and pushRemote then
    return pushRemote .. "/" .. current
  elseif current then
    return "pushRemote, setting that"
  end
end

local function upstream_description()
  local upstream = git.repo.upstream.ref

  if upstream then
    return upstream
  else
    return "@{upstream}, creating it"
  end
end

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
    :action("p", pushRemote_description(), actions.to_pushremote)
    :action("u", upstream_description(), actions.to_upstream)
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
