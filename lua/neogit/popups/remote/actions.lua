local M = {}

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local RemoteConfigPopup = require("neogit.popups.remote_config")

local operation = require("neogit.operations")

M.add = operation("add_remote", function(popup)
  local name = input.get_user_input("Remote name: ")
  if not name or name == "" then
    return
  end

  local origin = git.config.get("remote.origin.url").value
  local host, _, remote = origin:match("([^:/]+)[:/]([^/]+)/(.+)")

  remote = remote and remote:gsub("%.git$", "")

  local msg
  if host and remote then
    msg = string.format("%s:%s/%s.git", host, name, remote)
  end

  local remote_url = input.get_user_input("Remote url: ", msg)
  if not remote_url or remote_url == "" then
    return
  end

  local result = git.remote.add(name, remote_url, popup:get_arguments())

  if result.code ~= 0 then
    return
  end

  local set_default = input.get_confirmation(
    [[Set 'remote.pushDefault' to "]] .. name .. [["?]],
    { values = { "&Yes", "&No" }, default = 2 }
  )

  if set_default then
    git.config.set("remote.pushDefault", name)
    notification.info("Added remote " .. name .. " and set as pushDefault")
  else
    notification.info("Added remote " .. name)
  end
end)

function M.rename(_)
  local selected_remote = FuzzyFinderBuffer.new(git.remote.list()):open_async()
  if not selected_remote then
    return
  end

  local new_name = input.get_user_input("Rename " .. selected_remote .. " to: ")
  if not new_name or new_name == "" then
    return
  end

  git.remote.rename(selected_remote, new_name)
  notification.info("Renamed remote " .. selected_remote .. " to " .. new_name)
end

function M.remove(_)
  local selected_remote = FuzzyFinderBuffer.new(git.remote.list()):open_async()
  if not selected_remote then
    return
  end

  git.remote.remove(selected_remote)
  notification.info("Removed remote " .. selected_remote)
end

function M.configure(_)
  local remote_name = FuzzyFinderBuffer.new(git.remote.list()):open_async()
  if not remote_name then
    return
  end

  RemoteConfigPopup.create(remote_name)
end

function M.prune_branches(_)
  local selected_remote = FuzzyFinderBuffer.new(git.remote.list()):open_async()
  if not selected_remote then
    return
  end

  notification.info("Pruning remote " .. selected_remote)
  git.remote.prune(selected_remote)
end

-- https://github.com/magit/magit/blob/main/lisp/magit-remote.el#L159
-- All of something's refspecs are stale.  replace with [d]efault refspec, [r]emove remote, or [a]abort
-- function M.prune_refspecs()
-- end

-- https://github.com/magit/magit/blob/430a52c4b3f403ba8b0f97b4b67b868298dd60f3/lisp/magit-remote.el#L259
-- function M.update_default_branch()
-- end

-- https://github.com/magit/magit/blob/430a52c4b3f403ba8b0f97b4b67b868298dd60f3/lisp/magit-remote.el#L291
-- function M.unshallow_remote()
-- end

return M
