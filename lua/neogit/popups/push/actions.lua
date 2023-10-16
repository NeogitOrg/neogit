local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notification = require("neogit.lib.notification")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function push_to(args, remote, branch, opts)
  opts = opts or {}

  if opts.set_upstream then
    table.insert(args, "--set-upstream")
  end

  local name
  if branch then
    name = remote .. "/" .. branch
  else
    name = remote
  end

  logger.debug("Pushing to " .. name)
  notification.info("Pushing to " .. name)

  local res = git.push.push_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    logger.debug("Pushed to " .. name)
    notification.info("Pushed to " .. name, { dismiss = true })
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
    push_to(popup:get_arguments(), pushRemote, git.branch.current())
  end
end

function M.to_upstream(popup)
  local upstream = git.branch.upstream()
  local remote, branch, set_upstream

  if upstream then
    remote, branch = upstream:match("^([^/]*)/(.*)$")
  else
    set_upstream = true
    branch = git.branch.current()
    remote = git.branch.upstream_remote()
      or FuzzyFinderBuffer.new(git.remote.list()):open_async { prompt_prefix = "remote > " }
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
  if popup.state.env.commit then
    table.insert(sources, 1, popup.state.env.commit)
  end

  local source = FuzzyFinderBuffer.new(sources):open_async { prompt_prefix = "push > " }
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

  local remote, _ = destination:match("^([^/]*)/(.*)$")
  push_to(popup:get_arguments(), remote, source .. ":" .. destination)
end

function M.push_tags(popup)
  local remotes = git.remote.list()

  local remote
  if #remotes == 1 then
    remote = remotes[1]
  else
    remote = FuzzyFinderBuffer.new(remotes):open_async { prompt_prefix = "push tags to > " }
  end

  if remote then
    push_to({ "--tags", unpack(popup:get_arguments()) }, remote)
  end
end

function M.configure()
  require("neogit.popups.branch_config").create()
end

return M
