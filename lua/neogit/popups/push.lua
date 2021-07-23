local M = {}
local popup = require("neogit.lib.popup")
local input = require 'neogit.lib.input'
local status = require 'neogit.status'
local notif = require("neogit.lib.notification")
local git = require("neogit.lib.git")
local a = require 'plenary.async_lib'
local await, async, scheduler = a.await, a.async, a.scheduler

local http_url_patterns = {
  {
    pattern = "(https?)://(.*):(.*)@(.*)",
    handler = function(res)
      return {
        protocol = res[1],
        username = res[2],
        password = res[3],
        rest = res[4]
      }
    end
  },
  {
    pattern = "(https?)://(.*)@(.*)",
    handler = function(res)
      return {
        protocol = res[1],
        username = res[2],
        rest = res[3]
      }
    end
  },
  {
    pattern = "(https?)://(.*)",
    handler = function(res)
      return {
        protocol = res[1],
        rest = res[2]
      }
    end
  },
}

local get_remote_url = async(function(remote)
  local result, code = await(git.cli.remote.push.show_popup(false).get_url(remote).call())
  if code == 0 then
    local raw_url = result[1]
    if vim.startswith(raw_url, "http") then
      local raw_url = raw_url:gsub("www%.", "")
      for _, x in ipairs(http_url_patterns) do
        local res = {raw_url:match(x.pattern)}

        if #res > 0 then
          return x.handler(res)
        end
      end
    elseif vim.startswith(raw_url, "ssh") then
      local url = {}
      url.protocol, url.username, url.rest = raw_url:match("(.*)://(.*)@(.*)")
      return url
    elseif vim.startswith(raw_url, "git@") then
      local raw_url = raw_url:gsub("www%.", "")
      local url = { protocol = "git_ssh" }

      url.username, url.rest = raw_url:match("(.*)@(.*)")

      return url
    else
      error("TODO: unknown protocol")
    end
  else
    await(scheduler())
    notif.create(string.format("Remote '%s' doesn't exist", remote), { type = "error" })
  end
end)

local construct_url_str = function(url)
  if vim.startswith(url.protocol, "http") then
    if not url.username then
      url.username = input.get_user_input("Username: ")
      if not url.username then return end
    end

    if not url.password then
      url.password = input.get_secret_user_input("Password: ")
      if not url.password then return end
    end

    return string.format("%s://%s:%s@%s", url.protocol, url.username, url.password, url.rest)
  elseif url.protocol == "ssh" then
    return string.format("%s://%s@%s", url.protocol, url.username, url.rest)
  elseif url.protocol == "git_ssh" then
    return string.format("%s@%s", url.username, url.rest)
  else
    error("Unkown protocol")
  end
end

local push_to = async(function(popup, name, remote, branch)
  notif.create("Pushing to " .. name)

  local url = await(get_remote_url(remote))
  if not url then return end

  await(scheduler())
  local url_str = construct_url_str(url)
  if not url_str then return end

  local cmd = vim.startswith(url.protocol, "http")
    and git.cli.push.hide_text(url.password).args(unpack(popup:get_arguments())).args(url_str, branch)
    or git.cli.push.args(unpack(popup:get_arguments())).args(remote, branch)

  local _, code = await(cmd.call())
  if code == 0 then
    await(scheduler())
    notif.create("Pushed to " .. name)
    await(status.refresh(true))
  end
end)

function M.create()
  local p = popup.builder()
    :name("NeogitPushPopup")
    :switch("f", "force-with-lease", "Force with lease")
    :switch("F", "force", "Force")
    :switch("u", "set-upstream", "Set the upstream before pushing")
    :switch("h", "no-verify", "Disable hooks")
    :switch("d", "dry-run", "Dry run")
    :action("p", "Push to pushremote", function(popup)
      await(push_to(popup, "pushremote", "origin", status.repo.head.branch))
    end)
    :action("u", "Push to upstream", function(popup)
      await(push_to(popup, "upstream", "upstream", status.repo.head.branch))
    end)
    :action("e", "Push to elsewhere", function()
      local remote = input.get_user_input("remote: ")
      local branch = git.branch.prompt_for_branch()
      push_to(popup, remote, remote, branch)
    end)
    :build()

  p:show()
  
  return p
end

return M
