local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

---@class NeogitGitRemote
local M = {}

-- https://github.com/magit/magit/blob/main/lisp/magit-remote.el#LL141C32-L141C32
---@param remote string
---@param new_name string|nil
local function cleanup_push_variables(remote, new_name)
  if remote == git.config.get("remote.pushDefault"):read() then
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

---@param name string
---@param url string
---@param args string[]
---@return boolean
function M.add(name, url, args)
  return git.cli.remote.add.arg_list(args).args(name, url).call().code == 0
end

---@param from string
---@param to string
---@return boolean
function M.rename(from, to)
  local result = git.cli.remote.rename.arg_list({ from, to }).call()
  if result.code == 0 then
    cleanup_push_variables(from, to)
  end

  return result.code == 0
end

---@param name string
---@return boolean
function M.remove(name)
  local result = git.cli.remote.rm.args(name).call()
  if result.code == 0 then
    cleanup_push_variables(name)
  end

  return result.code == 0
end

---@param name string
---@return boolean
function M.prune(name)
  return git.cli.remote.prune.args(name).call().code == 0
end

---@return string[]
M.list = util.memoize(function()
  return git.cli.remote.call({ hidden = true }).stdout
end)

---@param name string
---@return string[]
function M.get_url(name)
  return git.cli.remote.get_url(name).call({ hidden = true }).stdout
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

  for _, v in pairs { "https", "http", "ssh", "git" } do
    if url:sub(1, #v + 3) == (v .. "://") then
      protocol = v
      break
    end
  end

  if protocol == nil then
    -- handle case where url is in the user@ form by translating it to ssh://user@
    -- note that this will fail for complex structures, but these would fail now as well.
    url = url:gsub("^(.*@[^:]+):(.+)$", "ssh://%1/%2")
    protocol = "ssh"
  end

  if protocol ~= nil then
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

    repository = url:match([[/([^/]+)%.git]]) or url:match([[/([^/]+)$]])
  end

  return { ---@type RemoteInfo
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
