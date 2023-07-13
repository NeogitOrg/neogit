local a = require("plenary.async")
local cli = require("neogit.lib.git.cli")
local config_lib = require("neogit.lib.git.config")
local input = require("neogit.lib.input")
local config = require("neogit.config")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

local function parse_branches(branches, include_current)
  local other_branches = {}

  local remotes = "^remotes/(.*)"
  local head = "^(.*)/HEAD"
  local ref = " %-> "
  local pattern = include_current and "^[* ] (.+)" or "^  (.+)"

  for _, b in ipairs(branches) do
    local branch_name = b:match(pattern)
    if branch_name then
      local name = branch_name:match(remotes) or branch_name
      if name and not name:match(ref) and not name:match(head) then
        table.insert(other_branches, name)
      end
    end
  end

  return other_branches
end

function M.get_local_branches(include_current)
  local branches = cli.branch.list(config.values.sort_branches).call_sync():trim().stdout

  return parse_branches(branches, include_current)
end

function M.get_remote_branches(include_current)
  local branches = cli.branch.remotes.list(config.values.sort_branches).call_sync():trim().stdout

  return parse_branches(branches, include_current)
end

function M.get_all_branches(include_current)
  local branches = cli.branch.list(config.values.sort_branches).all.call_sync():trim().stdout

  return parse_branches(branches, include_current)
end

function M.is_unmerged(branch, base)
  return cli.cherry.arg_list({ base or "master", branch }).call_sync():trim().stdout[1] ~= nil
end

function M.create()
  a.util.scheduler()
  local name = input.get_user_input("branch > ")
  if not name or name == "" then
    return
  end

  cli.branch.name(name:gsub("%s", "-")).call_interactive()

  return name
end

function M.current()
  local head = require("neogit.lib.git").repo.head.branch
  if head then
    return head
  else
    local branch_name = cli.branch.current.call_sync():trim().stdout
    if #branch_name > 0 then
      return branch_name[1]
    end
    return nil
  end
end

function M.pushRemote(branch)
  branch = branch or require("neogit.lib.git").repo.head.branch

  if branch then
    local remote = config_lib.get("branch." .. branch .. ".pushRemote")
    if remote:is_set() then
      return remote.value
    end
  end
end

function M.pushRemote_ref(branch)
  branch = branch or require("neogit.lib.git").repo.head.branch
  local pushRemote = M.pushRemote()

  if branch and pushRemote then
    return pushRemote .. "/" .. branch
  end
end

function M.pushRemote_label()
  return M.pushRemote_ref() or "pushRemote, setting that"
end

function M.set_pushRemote()
  local remotes = require("neogit.lib.git").remote.list()

  local pushRemote
  if #remotes == 1 then
    pushRemote = remotes[1]
  else
    pushRemote = FuzzyFinderBuffer.new(remotes):open_async { prompt_prefix = "set pushRemote > " }
  end

  if pushRemote then
    config_lib.set(
      string.format("branch.%s.pushRemote", require("neogit.lib.git").repo.head.branch),
      pushRemote
    )
  end

  return pushRemote
end

function M.upstream_label()
  return require("neogit.lib.git").repo.upstream.ref or "@{upstream}, creating it"
end

function M.upstream_remote()
  local git = require("neogit.lib.git")
  local remote = git.repo.upstream.remote

  if not remote then
    local remotes = git.remote.list()

    if git.config.get("push.autoSetupRemote").value == "true" and vim.tbl_contains(remotes, "origin") then
      remote = "origin"
    elseif #remotes == 1 then
      remote = remotes[1]
    else
      remote = FuzzyFinderBuffer.new(remotes):open_async { prompt_prefix = "remote > " }
    end
  end

  return remote
end

return M
