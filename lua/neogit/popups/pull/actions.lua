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

  notif.create("Pulling from " .. remote .. "/" .. branch)

  local res = git.pull.pull_interactive(remote, branch, args)

  if res and res.code == 0 then
    a.util.scheduler()
    notif.create("Pulled from " .. remote .. "/" .. branch)
    vim.cmd("do <nomodeline> User NeogitPullComplete")
  end

  status.refresh(true, "pull_from")
end

function M.pushRemote()
  return git.config.get("branch." .. git.branch.current() .. ".pushRemote").value
end

function M.configure()
  require("neogit.popups.branch_config").create()
end

function M.from_pushremote(popup)
  local pushRemote = M.pushRemote()
  local current = git.branch.current()

  if not pushRemote then
    local remote = FuzzyFinderBuffer.new(git.remote.list()):open_sync { prompt_prefix = "set pushRemote > " }
    if not remote then
      return
    end

    git.config.set("branch." .. current .. ".pushRemote", remote)
    pushRemote = remote
  end

  pull_from(popup:get_arguments(), pushRemote, current)
end

function M.from_upstream(popup)
  local args = popup:get_arguments()
  local upstream = git.branch.get_upstream()

  if not upstream.branch and not upstream.remote then
    local selected = FuzzyFinderBuffer.new(git.branch.get_remote_branches()):open_sync { prompt_prefix = "set upstream > " }
    if not selected then
      return
    end

    local remote, branch = unpack(vim.split(selected, "/"))
    pull_from(args, remote, branch, { set_upstream = true })
  else
    pull_from(args, upstream.remote, upstream.branch)
  end
end

function M.from_elsewhere(popup)
  local branches = git.branch.get_remote_branches()

  -- Maintain a set with all remotes we got branches for.
  local remote_options_set = {}
  for i, option in ipairs(branches) do
    if i ~= 1 then
      local match = option:match("^.-/")
      if match ~= nil then
        match = match:sub(1, -2)
        if not remote_options_set[match] then
          remote_options_set[match] = true
        end
      end
    end
  end

  local remote_options = {}
  local count = 0
  for k, _ in pairs(remote_options_set) do
    table.insert(remote_options, k)
    count = count + 1
  end

  local remote = nil
  if count == 1 then
    remote = remote_options[1]
    notif.create("Using remote " .. remote .. " because it is the only remote available")
  else
    remote = input.get_user_input_with_completion("remote: ", remote_options)
  end

  if not remote then
    notif.create("Aborting pull because there is no remote")
    return
  end

  -- Remove branches not under given remote.
  local branch_options = {}
  for i, option in ipairs(branches) do
    if i ~= 1 then
      local prefix = remote .. "/"
      if option:find("^" .. prefix) ~= nil then
        table.insert(branch_options, option)
      end
    end
  end

  local branch = git.branch.prompt_for_branch(branch_options, { truncate_remote_name_from_options = true })
  if not branch then
    notif.create("Aborting pull because there is no branch")
    return
  end

  pull_from(popup:get_arguments(), remote, branch)
end

return M
