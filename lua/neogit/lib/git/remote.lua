local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")
local a = require("plenary.async")

local M = {}

function M.add(name, url, args)
  a.util.scheduler()

  local result = cli.remote.add.arg_list({ unpack(args), name, url }).call()
  if result.code ~= 0 then
    notif.create("Couldn't add remote", vim.log.levels.ERROR)
  end

  return result
end

function M.rename(from, to)
  local result = cli.remote.rename.arg_list({ from, to }).call_sync()
  if result.code ~= 0 then
    notif.create("Couldn't rename remote", vim.log.levels.ERROR)
  else
    notif.create("Renamed '" .. from .. "' -> '" .. to .. "'", vim.log.levels.INFO)
  end

  return result
end

function M.remove(name)
  local result = cli.remote.rm.args(name).call_sync()
  if result.code ~= 0 then
    notif.create("Couldn't remove remote", vim.log.levels.ERROR)
  else
    notif.create("Removed remote '" .. name .. "'", vim.log.levels.INFO)
  end

  return result
end

function M.list()
  return cli.remote.call_sync():trim().stdout
end

return M
