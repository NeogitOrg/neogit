local cli = require("neogit.lib.git.cli")
local notification = require("neogit.lib.notification")
local a = require("plenary.async")

local M = {}

-- https://github.com/magit/magit/blob/main/lisp/magit-remote.el#LL141C32-L141C32
local function cleanup_push_variables(remote, new_name)
  local git = require("neogit.lib.git")

  if remote == git.config.get("remote.pushDefault").value then
    git.config.set("remote.pushDefault", new_name)
  end

  for key, var in pairs(git.config.get_matching("^branch%.[^.]*%.push[Rr]emote")) do
    if var.value == remote then
      if new_name then
        git.config.set(key, new_name)
      else
        git.config.unset(key)
      end
    end
  end
end

function M.add(name, url, args)
  a.util.scheduler()

  local result = cli.remote.add.arg_list(args).args(name, url).call()
  if result.code ~= 0 then
    notification.error("Couldn't add remote")
  else
    notification.info("Added remote '" .. name .. "'")
  end

  return result
end

function M.rename(from, to)
  local result = cli.remote.rename.arg_list({ from, to }).call_sync()
  if result.code ~= 0 then
    notification.error("Couldn't rename remote")
  else
    notification.info("Renamed '" .. from .. "' -> '" .. to .. "'")
    cleanup_push_variables(from, to)
  end

  return result
end

function M.remove(name)
  local result = cli.remote.rm.args(name).call_sync()
  if result.code ~= 0 then
    notification.error("Couldn't remove remote")
  else
    notification.info("Removed remote '" .. name .. "'")
    cleanup_push_variables(name)
  end

  return result
end

function M.prune(name)
  local result = cli.remote.prune.args(name).call_sync()
  if result.code ~= 0 then
    notification.error("Couldn't prune remote")
  else
    notification.info("Pruned remote '" .. name .. "'")
  end

  return result
end

function M.list()
  return cli.remote.call_sync():trim().stdout
end

function M.get_url(name)
  return cli.remote.get_url(name).call():trim().stdout
end

return M
