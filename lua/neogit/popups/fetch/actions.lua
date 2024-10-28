local M = {}

local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notification = require("neogit.lib.notification")
local util = require("neogit.lib.util")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local function select_remote()
  return FuzzyFinderBuffer.new(git.remote.list()):open_async { prompt_prefix = "remote" }
end

local function fetch_from(name, remote, branch, args)
  notification.info("Fetching from " .. name)
  local res = git.fetch.fetch_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    notification.info("Fetched from " .. name, { dismiss = true })
    logger.debug("Fetched from " .. name)
    vim.api.nvim_exec_autocmds("User", {
      pattern = "NeogitFetchComplete",
      modeline = false,
      data = { remote = remote, branch = branch },
    })
  else
    logger.error("Failed to fetch from " .. name)
  end
end

function M.fetch_pushremote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    pushRemote = git.branch.set_pushRemote()
  end

  if pushRemote then
    fetch_from(pushRemote, pushRemote, "", popup:get_arguments())
  end
end

function M.fetch_upstream(popup)
  local upstream = git.branch.upstream_remote()
  if upstream then
    fetch_from(upstream, upstream, "", popup:get_arguments())
  else
    upstream = select_remote()

    if upstream then
      local args = popup:get_arguments()
      table.insert(args, "--set-upstream")

      fetch_from(upstream, upstream, "", args)
    end
  end
end

function M.fetch_all_remotes(popup)
  local args = popup:get_arguments()
  table.insert(args, "--all")

  fetch_from("all remotes", "", "", args)
end

function M.fetch_elsewhere(popup)
  local remote = select_remote()
  if not remote then
    logger.error("No remote selected")
    return
  end

  fetch_from(remote, remote, "", popup:get_arguments())
end

-- TODO: add other URI's as options remotes in another_branch and refspec
--   https://
--   git://
--   git@

function M.fetch_another_branch(popup)
  local remote = select_remote()
  if not remote then
    return
  end

  local branches = util.filter_map(git.refs.list_branches(), function(branch)
    return branch:match("^" .. remote .. "/(.*)")
  end)

  local branch = FuzzyFinderBuffer.new(branches):open_async {
    prompt_prefix = remote .. "/{branch}",
  }
  if not branch then
    return
  end

  fetch_from(remote .. "/" .. branch, remote, branch, popup:get_arguments())
end

function M.fetch_refspec(popup)
  local remote = select_remote()
  if not remote then
    return
  end

  notification.info("Determining refspecs...")
  local refspecs = util.map(git.cli["ls-remote"].remote(remote).call({ hidden = true }).stdout, function(ref)
    return vim.split(ref, "\t")[2]
  end)
  notification.delete_all()

  local refspec = FuzzyFinderBuffer.new(refspecs):open_async { prompt_prefix = "refspec" }
  if not refspec then
    return
  end

  fetch_from(remote .. " " .. refspec, remote, refspec, popup:get_arguments())
end

function M.fetch_submodules(_)
  notification.info("Fetching submodules")
  git.cli.fetch.recurse_submodules.verbose.jobs(4).call()
end

function M.set_variables()
  require("neogit.popups.branch_config").create()
end

return M
