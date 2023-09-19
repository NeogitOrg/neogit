local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notification = require("neogit.lib.notification")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function pull_from(args, remote, branch, opts)
  opts = opts or {}

  if opts.set_upstream then
    table.insert(args, "--set-upstream")
  end

  local name = remote .. "/" .. branch

  notification.info("Pulling from " .. name)
  logger.debug("Pulling from " .. name)

  local res = git.pull.pull_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    notification.info("Pulled from " .. name, { dismiss = true })
    logger.debug("Pulled from " .. name)
    vim.api.nvim_exec_autocmds("User", { pattern = "NeogitPullComplete", modeline = false })
  else
    logger.error("Failed to pull from " .. name)
  end
end

function M.from_pushremote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    pushRemote = git.branch.set_pushRemote()
  end

  if pushRemote then
    pull_from(popup:get_arguments(), pushRemote, git.repo.head.branch)
  end
end

function M.from_upstream(popup)
  local upstream = git.repo.upstream.ref
  local set_upstream

  if not upstream then
    set_upstream = true
    upstream = FuzzyFinderBuffer.new(git.branch.get_remote_branches()):open_async {
      prompt_prefix = "set upstream > ",
    }

    if not upstream then
      return
    end
  end

  local remote, branch = upstream:match("^([^/]*)/(.*)$")
  pull_from(popup:get_arguments(), remote, branch, { set_upstream = set_upstream })
end

function M.from_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.branch.get_remote_branches())
    :open_async { prompt_prefix = "pull > " }
  if not target then
    return
  end

  local remote, branch = target:match("^([^/]*)/(.*)$")
  pull_from(popup:get_arguments(), remote, branch)
end

function M.configure()
  require("neogit.popups.branch_config").create()
end

return M
