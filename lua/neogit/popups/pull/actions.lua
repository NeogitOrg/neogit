local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notif = require("neogit.lib.notification")
local status = require("neogit.status")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function pull_from(args, remote, branch, opts)
  opts = opts or {}

  if opts.set_upstream then
    table.insert(args, "--set-upstream")
  end

  local name = remote .. "/" .. branch

  notif.create("Pulling from " .. name)
  logger.debug("Pulling from " .. name)

  local res = git.pull.pull_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    notif.create("Pulled from " .. name)
    logger.debug("Pulled from " .. name)
    status.refresh(true, "pull_from")
    vim.cmd("do <nomodeline> User NeogitPullComplete")
  else
    logger.error("Failed to pull from " .. name)
  end
end

function M.from_pushremote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    pushRemote = FuzzyFinderBuffer.new(git.remote.list()):open_sync { prompt_prefix = "set pushRemote > " }
    if not pushRemote then
      return
    end

    git.config.set("branch." .. status.repo.head.branch .. ".pushRemote", pushRemote)
  end

  pull_from(popup:get_arguments(), pushRemote, status.repo.head.branch)
end

function M.from_upstream(popup)
  local upstream = status.repo.upstream.branch
  local set_upstream

  if not upstream then
    set_upstream = true
    upstream = FuzzyFinderBuffer.new(git.branch.get_remote_branches()):open_sync {
      prompt_prefix = "set upstream > "
    }

    if not upstream then
      return
    end
  end

  local remote, branch = unpack(vim.split(upstream, "/"))
  pull_from(popup:get_arguments(), remote, branch, { set_upstream = set_upstream })
end

function M.from_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.branch.get_remote_branches()):open_sync { prompt_prefix = "pull > " }
  if not target then
    return
  end

  local remote, branch = unpack(vim.split(target, "/"))
  pull_from(popup:get_arguments(), remote, branch)
end

function M.configure()
  require("neogit.popups.branch_config").create()
end

return M
