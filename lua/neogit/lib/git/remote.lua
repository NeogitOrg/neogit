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

---@class RemoteInfo
---@field url string
---@field protocol string
---@field user string
---@field host string
---@field port string
---@field path string
---@field repo string
---@field owner string
---@field repository string

---@param url string
---@return RemoteInfo
function M.parse(url)
  local protocol, user, host, port, path, repository, owner

  for _, v in pairs { "git", "https", "http", "ssh" } do
    if url:sub(1, #v) == v then
      protocol = v
      break
    end
  end

  if protocol ~= nil then
    if protocol == "git" then
      user = "git"
      host = url:match([[@([^:]+)]])
      owner = url:match([[:([^/]+)/]])
    else
      user = url:match([[://(%w+):?%w*@]]) -- Strip passwords.
      port = url:match([[:(%d+)]])

      if user ~= nil and port ~= nil then
        host = url:match([[@(.*):]])
      elseif user ~= nil then
        host = url:match([[@(.-)/]])
      elseif port ~= nil then
        host = url:match([[//(.-):]])
      else
        host = url:match([[//(.-)/]])
      end

      path = url:sub(#protocol + 4, #url):match([[/(.*)/]])
      owner = path -- Strictly for backwards compatibility.
    end

    repository = url:match([[/([^/]+)%.git]])
  end

  return {
    url = url,
    protocol = protocol,
    user = user,
    host = host,
    port = port,
    path = path,
    repo = repository,
    owner = owner,
    repository = repository,
  }
end

return M
