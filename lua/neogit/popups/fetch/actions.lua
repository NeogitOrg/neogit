local M = {}

local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notif = require("neogit.lib.notification")
local status = require("neogit.status")
local util = require("neogit.lib.util")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local function fetch_from(name, remote, branch, args)
  notif.create("Fetching from " .. name)
  local res = git.fetch.fetch_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    notif.create("Fetched from " .. name)
    logger.debug("Fetched from " .. name)
    status.refresh(true, "fetch_from")
    vim.cmd("do <nomodeline> User NeogitFetchComplete")
  else
    logger.error("Failed to fetch from " .. name)
  end
end

function M.fetch_from_pushremote(popup)
  local pushRemote = git.branch.pushRemote()
  if not pushRemote then
    local remotes = git.remote.list()

    pushRemote = FuzzyFinderBuffer.new(remotes):open_sync { prompt_prefix = "set pushRemote > " }
    if not pushRemote then
      logger.error("No pushremote set")
      return
    end

    git.config.set("branch." .. git.repo.head.branch .. ".pushRemote", pushRemote)
  end

  fetch_from(pushRemote, pushRemote, "", popup:get_arguments())
end

function M.upstream()
  local upstream = git.repo.upstream.remote
  if upstream then
    return upstream
  end

  local remotes = git.remote.list()
  if #remotes == 1 then
    return remotes[1]
  elseif vim.tbl_contains(remotes, "origin") then
    return "origin"
  else
    return nil
  end
end

function M.fetch_from_upstream(popup)
  local upstream = M.upstream()

  if upstream then
    fetch_from(upstream, upstream, "", popup:get_arguments())
  end
end

function M.fetch_from_all_remotes(popup)
  local args = popup:get_arguments()
  table.insert(args, "--all")

  fetch_from("all remotes", "", "", args)
end

function M.fetch_from_elsewhere(popup)
  local remote = FuzzyFinderBuffer.new(git.remote.list()):open_sync { prompt_prefix = "remote > " }
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
  local remote = FuzzyFinderBuffer.new(git.remote.list()):open_sync { prompt_prefix = "remote > " }
  if not remote then
    return
  end

  local branches = util.filter_map(git.branch.get_all_branches(true), function(branch)
    return branch:match("^" .. remote .. "/(.*)")
  end)

  local branch = FuzzyFinderBuffer.new(branches):open_sync {
    prompt_prefix = remote .. "/{branch} > ",
  }
  if not branch then
    return
  end

  fetch_from(remote .. "/" .. branch, remote, branch, popup:get_arguments())
end

function M.fetch_refspec(popup)
  local remote = FuzzyFinderBuffer.new(git.remote.list()):open_sync { prompt_prefix = "remote > " }
  if not remote then
    return
  end

  notif.create("Determining refspecs...")
  local refspecs = util.map(git.cli["ls-remote"].remote(remote).call():trim().stdout, function(ref)
    return vim.split(ref, "\t")[2]
  end)

  local refspec = FuzzyFinderBuffer.new(refspecs):open_sync { prompt_prefix = "refspec > " }
  if not refspec then
    return
  end

  fetch_from(remote .. " " .. refspec, remote, refspec, popup:get_arguments())
end

function M.fetch_submodules(_)
  notif.create("Fetching submodules")
  git.cli.fetch.recurse_submodules().verbose().jobs(4).call()
  status.refresh(true, "fetch_submodules")
end

function M.set_variables()
  require("neogit.popups.branch_config").create()
end

return M
