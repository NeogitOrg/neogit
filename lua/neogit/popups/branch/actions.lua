local M = {}

local status = require("neogit.status")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local notif = require("neogit.lib.notification")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local BranchConfigPopup = require("neogit.popups.branch_config")

local function parse_remote_branch_name(remote_name)
  local offset = remote_name:find("/")
  if not offset then
    return nil, remote_name
  end

  local remote = remote_name:sub(1, offset - 1)
  local branch_name = remote_name:sub(offset + 1, remote_name:len())

  return remote, branch_name
end

function M.checkout_branch_revision()
  local selected_branch = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_sync()
  git.cli.checkout.branch(selected_branch).call_sync():trim()

  status.refresh(true, "checkout_branch")
end

function M.checkout_local_branch()
  local local_branches = git.branch.get_local_branches()
  local remote_branches = util.filter_map(git.branch.get_remote_branches(), function(name)
    local branch_name = name:match([[%/(.*)$]])
    -- Remove remote branches that have a local branch by the same name
    if branch_name and not vim.tbl_contains(local_branches, branch_name) then
      return name
    end
  end)

  local target = FuzzyFinderBuffer.new(util.merge(local_branches, remote_branches)):open_sync { prompt_prefix = " branch > " }
  if target:match([[/]]) then
    git.cli.checkout.track(target).call_sync()
  elseif target then
    git.cli.checkout.branch(target).call_sync()
  end

  status.refresh(true, "branch_checkout")
end

function M.checkout_create_branch()
  local branches = git.branch.get_all_branches(false)
  local current_branch = git.branch.current()
  if current_branch then
    table.insert(branches, 1, current_branch)
  end

  local name = input.get_user_input("branch > ")
  if not name or name == "" then
    return
  end
  name, _ = name:gsub("%s", "-")

  local base_branch = FuzzyFinderBuffer.new(branches):open_sync { prompt_prefix = " base branch > " }
  git.cli.checkout.new_branch_with_start_point(name, base_branch).call_sync():trim()
  status.refresh(true, "branch_create")
end

function M.create_branch()
  git.branch.create()
  status.refresh(true, "create_branch")
end

function M.configure_branch()
  local branch_name = FuzzyFinderBuffer.new(git.branch.get_local_branches(true)):open_sync()
  if not branch_name then
    return
  end

  BranchConfigPopup.create(branch_name)
end

function M.rename_branch()
  local current_branch = git.branch.current()
  local branches = git.branch.get_local_branches()
  if current_branch then
    table.insert(branches, 1, current_branch)
  end

  local selected_branch = FuzzyFinderBuffer.new(branches):open_sync()
  local new_name = input.get_user_input("new branch name > ")
  if not new_name or new_name == "" then
    return
  end

  new_name, _ = new_name:gsub("%s", "-")
  git.cli.branch.move.args(selected_branch, new_name).call_sync():trim()
  status.refresh(true, "rename_branch")
end

function M.reset_branch()
  local repo = require("neogit.status").repo
  if #repo.staged.items > 0 or #repo.unstaged.items > 0 then
    local confirmation = input.get_confirmation(
      "Uncommitted changes will be lost. Proceed?",
      { values = { "&Yes", "&No" }, default = 2 }
    )
    if not confirmation then
      return
    end
  end

  local branches = git.branch.get_all_branches(false)
  local to = FuzzyFinderBuffer.new(branches):open_sync {
    prompt_prefix = " reset " .. git.branch.current() .. " to > ",
  }

  if not to then
    return
  end

  -- Reset the current branch to the desired state
  git.cli.reset.hard.args(to).call_sync()

  -- Update reference
  local from = git.cli["rev-parse"].symbolic_full_name.args(git.branch.current()).call_sync():trim().stdout[1]
  git.cli["update-ref"].message(string.format("reset: moving to %s", to)).args(from, to).call_sync()

  notif.create(string.format("Reset '%s'", git.branch.current()), vim.log.levels.INFO)
  status.refresh(true, "reset_branch")
end

function M.delete_branch()
  -- TODO: If branch is checked out:
  -- Branch gha-routes-js is checked out.  [d]etach HEAD & delete, [c]heckout origin/gha-routes-js & delete, [a]bort
  local branches = git.branch.get_all_branches()
  local selected_branch = FuzzyFinderBuffer.new(branches):open_sync()
  if not selected_branch then
    return
  end

  local remote, branch_name = parse_remote_branch_name(selected_branch)
  git.cli.branch.delete.name(branch_name).call_sync():trim()

  if remote and input.get_confirmation("Delete remote?", { values = { "&Yes", "&No" }, default = 2 }) then
    git.cli.push.remote(remote).delete.to(branch_name).call_sync():trim()
  end

  notif.create(string.format("Deleted branch '%s'", branch_name), vim.log.levels.INFO)
  status.refresh(true, "delete_branch")
end

return M
