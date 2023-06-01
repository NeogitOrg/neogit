local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notif = require("neogit.lib.notification")
local status = require("neogit.status")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function push_to(args, remote, branch, opts)
  opts = opts or {}

  if opts.set_upstream then
    table.insert(args, "--set-upstream")
  end

  local name = remote .. "/" .. branch

  logger.debug("Pushing to " .. name)
  notif.create("Pushing to " .. name)

  local res = git.push.push_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    logger.error("Pushed to " .. name)
    notif.create("Pushed to " .. name)
    status.refresh(true, "push_to")
    vim.cmd("do <nomodeline> User NeogitPushComplete")
  else
    logger.error("Failed to push to " .. name)
  end
end

function M.to_pushremote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    pushRemote = FuzzyFinderBuffer.new(git.remote.list()):open_sync { prompt_prefix = "set pushRemote > " }
    if not pushRemote then
      return
    end

    git.config.set("branch." .. status.repo.head.branch .. ".pushRemote", pushRemote)
  end

  push_to(popup:get_arguments(), pushRemote, status.repo.head.branch)
end

function M.to_upstream(popup)
  local upstream = status.repo.upstream.branch
  local remote, branch, set_upstream

  if upstream then
    remote, branch = unpack(vim.split(upstream, "/"))
  else
    set_upstream = true
    branch = status.repo.head.branch

    local result = git.config.get("push.autoSetupRemote").value
    if result and result == "true" then
      remote = "origin"
    else
      remote = FuzzyFinderBuffer.new(git.remote.list()):open_sync { prompt_prefix = "remote > " }
      if not remote then
        logger.error("No upstream set")
        return
      end
    end
  end

  push_to(popup:get_arguments(), remote, branch, { set_upstream = set_upstream })
end

function M.to_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.branch.get_remote_branches())
    :open_sync { prompt_prefix = "push > " }
  if not target then
    return
  end

  local remote, branch = unpack(vim.split(target, "/"))
  push_to(popup:get_arguments(), remote, branch)
end

function M.push_other(popup)
  local sources = git.branch.get_local_branches()
  table.insert(sources, "HEAD")
  table.insert(sources, "ORIG_HEAD")
  table.insert(sources, "FETCH_HEAD")

  local source = FuzzyFinderBuffer.new(sources):open_sync {
    prompt_prefix = "push > ",
  }
  if not source then
    return
  end

  local destinations = git.branch.get_remote_branches()
  for _, remote in ipairs(git.remote.list()) do
    table.insert(destinations, 1, remote .. "/" .. source)
  end

  local destination = FuzzyFinderBuffer.new(destinations)
    :open_sync { prompt_prefix = "push " .. source .. " to > " }
  if not destination then
    return
  end

  local remote, _ = unpack(vim.split(destination, "/"))
  push_to(popup:get_arguments(), remote, source .. ":" .. destination)
end

function M.configure()
  require("neogit.popups.branch_config").create()
end

return M
