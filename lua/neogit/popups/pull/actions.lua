local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notification = require("neogit.lib.notification")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

---@param args string[]
---@param remote string
---@param branch string
---@param opts table|nil
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
    notification.error("Failed to pull from " .. name, { dismiss = true })
    if res.code == 128 then
      notification.info(table.concat(res.stdout, "\n"))
      return
    end
  end
end

function M.from_pushremote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    pushRemote = git.branch.set_pushRemote()
  end

  local current = git.branch.current()
  if pushRemote and current then
    pull_from(popup:get_arguments(), pushRemote, current)
  end
end

function M.from_upstream(popup)
  local upstream = git.repo.state.upstream.ref
  local set_upstream

  if not upstream then
    set_upstream = true
    upstream = FuzzyFinderBuffer.new(git.refs.list_remote_branches()):open_async {
      prompt_prefix = "set upstream",
    }

    if not upstream then
      return
    end
  end

  local remote, branch = git.branch.parse_remote_branch(upstream)
  if remote and branch then
    pull_from(popup:get_arguments(), remote, branch, { set_upstream = set_upstream })
  end
end

function M.from_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.refs.list_remote_branches()):open_async { prompt_prefix = "pull" }
  if not target then
    return
  end

  local remote, branch = git.branch.parse_remote_branch(target)
  if remote and branch then
    pull_from(popup:get_arguments(), remote, branch)
  end
end

function M.configure()
  require("neogit.popups.branch_config").create()
end

return M
