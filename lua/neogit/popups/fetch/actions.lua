local M = {}

local a = require("plenary.async")
local git = require("neogit.lib.git")
local logger = require("neogit.logger")
local notif = require("neogit.lib.notification")
local status = require("neogit.status")

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

    -- TODO: add other URI's as options
    pushRemote = FuzzyFinderBuffer.new(remotes):open_sync { prompt_prefix = "set pushRemote > " }
    if not pushRemote then
      logger.error("No pushremote set")
      return
    end

    git.config.set("branch." .. git.repo.head.branch .. ".pushRemote", pushRemote)
  end

  fetch_from(pushRemote, pushRemote, "", popup:get_arguments())
end

function M.fetch_from_upstream(popup)
  local upstream = git.repo.upstream.remote
  local args = popup:get_arguments()

  if not upstream then
    table.insert(args, "--set-upstream")
    upstream = FuzzyFinderBuffer.new(git.remote.list()):open_sync {
      prompt_prefix = "set upstream > ",
    }

    if not upstream then
      return
    end
  end


  fetch_from(upstream, upstream, "", args)
end

function M.fetch_from_all_remotes(popup)
  local args = popup:get_arguments()
  table.insert(args, "--all")

  fetch_from("all remotes", "", "", args)
end

function M.fetch_from_elsewhere(popup)
  local remote = FuzzyFinderBuffer.new(git.remote.list()):open_sync { prompt_prefix = "remote > " }
  if not remote then
    logger.error("No remote set")
    return
  end

  fetch_from(remote, remote, "", popup:get_arguments())
end

-- TODO: Select remote, then select branch in second popup
-- running `git fetch <remote> <branch>`
-- function M.another_branch(popup)
-- end

function M.set_variables()
  require("neogit.popups.branch_config").create()
end

return M
