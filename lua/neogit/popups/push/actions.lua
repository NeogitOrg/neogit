local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notification = require("neogit.lib.notification")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local config = require("neogit.config")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function push_to(args, remote, branch, opts)
  opts = opts or {}

  if opts.set_upstream or git.push.auto_setup_remote(branch) then
    table.insert(args, "--set-upstream")
  end

  if vim.tbl_contains(args, "--force-with-lease") then
    table.insert(args, "--force-if-includes")
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

  -- Inform the user about missing permissions
  if res.code == 128 then
    notification.info(table.concat(res.stdout, "\n"))
    return
  end

  local using_force = vim.tbl_contains(args, "--force") or vim.tbl_contains(args, "--force-with-lease")
  local updates_rejected = string.find(table.concat(res.stdout), "Updates were rejected") ~= nil

  -- Only ask the user whether to force push if not already specified and feature enabled
  if res and res.code ~= 0 and not using_force and updates_rejected and config.values.prompt_force_push then
    logger.error("Attempting force push to " .. name)

    local message = "Your branch has diverged from the remote branch. Do you want to force push?"
    if input.get_permission(message) then
      table.insert(args, "--force")
      res = git.push.push_interactive(remote, branch, args)
    end
  end

  if res and res.code == 0 then
    a.util.scheduler()
    logger.debug("Pushed to " .. name)
    notification.info("Pushed to " .. name, { dismiss = true })
    vim.api.nvim_exec_autocmds("User", { pattern = "NeogitPushComplete", modeline = false })
  else
    logger.debug("Failed to push to " .. name)
    notification.error("Failed to push to " .. name, { dismiss = true })
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
    remote, branch = git.branch.parse_remote_branch(upstream)
  else
    set_upstream = true
    branch = git.branch.current()
    remote = git.branch.upstream_remote()
      or FuzzyFinderBuffer.new(git.remote.list()):open_async { prompt_prefix = "remote" }
  end

  if remote then
    push_to(popup:get_arguments(), remote, branch, { set_upstream = set_upstream })
  else
    logger.error("No upstream set")
  end
end

function M.to_elsewhere(popup)
  local target = FuzzyFinderBuffer.new(git.refs.list_remote_branches()):open_async {
    prompt_prefix = "push",
  }

  if target then
    local remote, branch = git.branch.parse_remote_branch(target)
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

  local source = FuzzyFinderBuffer.new(sources):open_async { prompt_prefix = "push" }
  if not source then
    return
  end

  local destinations = git.refs.list_remote_branches()
  for _, remote in ipairs(git.remote.list()) do
    table.insert(destinations, 1, remote .. "/" .. source)
  end

  local destination = FuzzyFinderBuffer.new(destinations)
    :open_async { prompt_prefix = "push " .. source .. " to" }
  if not destination then
    return
  end

  local remote, _ = git.branch.parse_remote_branch(destination)
  push_to(popup:get_arguments(), remote, source .. ":" .. destination)
end

---@param prompt string
---@return string|nil
local function choose_remote(prompt)
  local remotes = git.remote.list()
  local remote
  if #remotes == 1 then
    remote = remotes[1]
  else
    remote = FuzzyFinderBuffer.new(remotes):open_async { prompt_prefix = prompt }
  end

  return remote
end

---@param popup PopupData
function M.push_a_tag(popup)
  local tags = git.tag.list()

  local tag = FuzzyFinderBuffer.new(tags):open_async { prompt_prefix = "Push tag" }
  if not tag then
    return
  end

  local remote = choose_remote(("Push %s to remote"):format(tag))
  if remote then
    push_to({ tag, unpack(popup:get_arguments()) }, remote)
  end
end

---@param popup PopupData
function M.push_all_tags(popup)
  local remote = choose_remote("Push tags to remote")
  if remote then
    push_to({ "--tags", unpack(popup:get_arguments()) }, remote)
  end
end

---@param popup PopupData
function M.matching_branches(popup)
  local remote = choose_remote("Push matching branches to")
  if remote then
    push_to({ "-v", unpack(popup:get_arguments()) }, remote, ":")
  end
end

---@param popup PopupData
function M.explicit_refspec(popup)
  local remote = choose_remote("Push to remote")
  if not remote then
    return
  end

  local options = util.merge({ "HEAD" }, git.refs.list_local_branches())
  local refspec = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Push refspec" }
  if refspec then
    push_to({ "-v", unpack(popup:get_arguments()) }, remote, refspec)
  end
end

function M.configure()
  require("neogit.popups.branch_config").create()
end

return M
