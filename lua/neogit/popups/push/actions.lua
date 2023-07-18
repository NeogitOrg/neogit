local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notif = require("neogit.lib.notification")

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
    logger.error("Pushed to " .. name)
    notif.create("Pushed to " .. name)
    vim.api.nvim_exec_autocmds("User", { pattern = "NeogitPushComplete", modeline = false })
  else
    logger.error("Failed to push to " .. name)
  end
end

function M.to_pushremote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    pushRemote = git.branch.set_pushRemote()
  end

  if pushRemote then
    push_to(popup:get_arguments(), pushRemote, git.repo.head.branch)
  end
end

function M.to_upstream(popup)
  local upstream = git.repo.upstream.ref
  local remote, branch, set_upstream

  if upstream then
    remote, branch = upstream:match("^([^/]*)/(.*)$")
  else
    set_upstream = true
    branch = git.repo.head.branch
    remote = git.branch.upstream_remote()
  end

  if remote then
    push_to(popup:get_arguments(), remote, branch, { set_upstream = set_upstream })
  else
    logger.error("No upstream set")
  end
end

function M.to_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.branch.get_remote_branches()):open_async {
    prompt_prefix = "push > ",
  }

  if target then
    local remote, branch = target:match("^([^/]*)/(.*)$")
    push_to(popup:get_arguments(), remote, branch)
  end
end

function M.push_other(popup)
  local sources = git.branch.get_local_branches()
  table.insert(sources, "HEAD")
  table.insert(sources, "ORIG_HEAD")
  table.insert(sources, "FETCH_HEAD")

  local source = FuzzyFinderBuffer.new(sources):open_async {
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
    :open_async { prompt_prefix = "push " .. source .. " to > " }
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
