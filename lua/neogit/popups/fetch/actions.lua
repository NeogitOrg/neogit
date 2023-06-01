local M = {}

local a = require("plenary.async")
local git = require("neogit.lib.git")
local notif = require("neogit.lib.notification")
local input = require("neogit.lib.input")

local function fetch_from(name, remote, branch, args)
  notif.create("Fetching from " .. name)
  local res = git.fetch.fetch_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    notif.create("Fetched from " .. name)
    vim.cmd("do <nomodeline> User NeogitFetchComplete")
  end
end

function M.fetch_from_pushremote(popup)
  fetch_from(
    "pushremote",
    "origin",
    git.repo.head.branch,
    popup:get_arguments()
  )
end

function M.fetch_from_upstream(popup)
  local upstream = git.repo.upstream.ref
  if not upstream then
    return
  end

  fetch_from(git.repo.upstream.ref, git.repo.upstream.remote, "", popup:get_arguments())
end

function M.fetch_from_all_remotes(popup)
  fetch_from("all remotes", "", "", { unpack(popup:get_arguments()), "--all" })
end

-- TODO: Update to use fuzzy branch picker/remote picker
function M.fetch_from_elsewhere(popup)
  local remote = input.get_user_input("remote: ")
  local branch = git.branch.prompt_for_branch()
  fetch_from(remote .. " " .. branch, remote, branch, popup:get_arguments())
end

function M.set_variables()
  require("neogit.popups.branch_config").create()
end

return M
