local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

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
  return cli.remote.add.arg_list(args).args(name, url).call().code == 0
end

function M.rename(from, to)
  local result = cli.remote.rename.arg_list({ from, to }).call_sync()
  if result.code == 0 then
    cleanup_push_variables(from, to)
  end

  return result.code == 0
end

function M.remove(name)
  local result = cli.remote.rm.args(name).call_sync()
  if result.code == 0 then
    cleanup_push_variables(name)
  end

  return result.code == 0
end

function M.prune(name)
  return cli.remote.prune.args(name).call().code == 0
end

M.list = util.memoize(function()
  return cli.remote.call_sync({ hidden = false }).stdout
end)

function M.get_url(name)
  return cli.remote.get_url(name).call({ hidden = true }).stdout
end

function M.parse(url)
  local info = {
    url = url,
    proto = nil,
    user = nil,
    host = nil,
    port = nil,
    path = nil,
    repo = nil,
    owner = nil,
    repository = nil,
  }
  for _, v in pairs { "git", "https", "http", "ssh" } do
    if url:sub(1, #v) == v then
      info.proto = v
      break
    end
  end
  if info.proto ~= nil then
    if info.proto == "git" then
      info.user = "git"
      info.host = url:match([[@([^:]+)]])
      info.owner = url:match([[:(%w+)/]])
    else
      info.user = url:match([[://(%w+):?%w*@]]) -- Strip passwords.
      info.port = url:match([[:(%d+)]])
      if info.user ~= nil and info.port ~= nil then
        info.host = url:match([[@(.*):]])
      elseif info.user ~= nil then
        info.host = url:match([[@(.-)/]])
      elseif info.port ~= nil then
        info.host = url:match([[//(.-):]])
      else
        info.host = url:match([[//(.-)/]])
      end
      info.path = url:sub(#info.proto + 4, #url):match([[/(.*)/]])
      info.owner = info.path -- Strictly for backwards compatibility.
    end
    info.repo = url:match([[/(%w+).git]])
  end
  info.repository = info.repo
  return info
end

return M
