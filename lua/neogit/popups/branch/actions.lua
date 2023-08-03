local M = {}

local status = require("neogit.status")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local notif = require("neogit.lib.notification")
local operation = require("neogit.operations")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local BranchConfigPopup = require("neogit.popups.branch_config")

local function parse_remote_branch_name(ref)
  local offset = ref:find("/")
  if not offset then
    return nil, ref
  end

  local remote = ref:sub(1, offset - 1)
  local branch_name = ref:sub(offset + 1, ref:len())

  return remote, branch_name
end

local function spin_off_branch(checkout)
  if git.status.is_dirty() and not checkout then
    notif.create("Staying on HEAD due to uncommitted changes", vim.log.levels.INFO)
    checkout = true
  end

  local name = input.get_user_input("branch > ")
  if not name or name == "" then
    return
  end

  name, _ = name:gsub("%s", "-")
  git.branch.create(name)

  local current_branch_name = git.branch.current_full_name()

  if checkout then
    git.cli.checkout.branch(name).call_sync()
  end

  local upstream = git.branch.upstream()
  if upstream then
    if checkout then
      git.log.update_ref(current_branch_name, upstream)
    else
      git.cli.reset.hard.args(upstream).call()
    end
  end
end

M.spin_off_branch = operation("spin_off_branch", function()
  spin_off_branch(true)
  status.refresh(true, "spin_off_branch")
end)

M.spin_out_branch = operation("spin_out_branch", function()
  spin_off_branch(false)
  status.refresh(true, "spin_out_branch")
end)

M.checkout_branch_revision = operation("checkout_branch_revision", function(popup)
  local selected_branch = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_async()
  if not selected_branch then
    return
  end

  git.cli.checkout.branch(selected_branch).arg_list(popup:get_arguments()).call_sync():trim()
  status.refresh(true, "checkout_branch")
end)

M.checkout_local_branch = operation("checkout_local_branch", function(popup)
  local local_branches = git.branch.get_local_branches()
  local remote_branches = util.filter_map(git.branch.get_remote_branches(), function(name)
    local branch_name = name:match([[%/(.*)$]])
    -- Remove remote branches that have a local branch by the same name
    if branch_name and not vim.tbl_contains(local_branches, branch_name) then
      return name
    end
  end)

  local target = FuzzyFinderBuffer.new(util.merge(local_branches, remote_branches)):open_async {
    prompt_prefix = " branch > ",
  }

  if not target then
    return
  end

  if target:match([[/]]) then
    git.cli.checkout.track(target).arg_list(popup:get_arguments()).call_sync()
  elseif target then
    git.cli.checkout.branch(target).arg_list(popup:get_arguments()).call_sync()
  end

  status.refresh(true, "branch_checkout")
end)

M.checkout_create_branch = operation("checkout_create_branch", function()
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

  local base_branch = FuzzyFinderBuffer.new(branches):open_async { prompt_prefix = " base branch > " }
  if not base_branch then
    return
  end

  git.cli.checkout.new_branch_with_start_point(name, base_branch).call_sync()
  status.refresh(true, "branch_create")
end)

M.create_branch = operation("create_branch", function()
  local name = input.get_user_input("branch > ")
  if not name or name == "" then
    return
  end

  name, _ = name:gsub("%s", "-")
  git.branch.create(name)
  status.refresh(true, "create_branch")
end)

M.configure_branch = operation("configure_branch", function()
  local branch_name = FuzzyFinderBuffer.new(git.branch.get_local_branches(true)):open_async()
  if not branch_name then
    return
  end

  BranchConfigPopup.create(branch_name)
end)

M.rename_branch = operation("rename_branch", function()
  local current_branch = git.repo.head.branch
  local branches = git.branch.get_local_branches()
  if current_branch then
    table.insert(branches, 1, current_branch)
  end

  local selected_branch = FuzzyFinderBuffer.new(branches):open_async()
  if not selected_branch then
    return
  end

  local new_name = input.get_user_input("new branch name > ")
  if not new_name or new_name == "" then
    return
  end

  new_name, _ = new_name:gsub("%s", "-")
  git.cli.branch.move.args(selected_branch, new_name).call_sync():trim()
  status.refresh(true, "rename_branch")
end)

M.reset_branch = operation("reset_branch", function()
  if #git.repo.staged.items > 0 or #git.repo.unstaged.items > 0 then
    local confirmation = input.get_confirmation(
      "Uncommitted changes will be lost. Proceed?",
      { values = { "&Yes", "&No" }, default = 2 }
    )
    if not confirmation then
      return
    end
  end

  local branches = git.branch.get_all_branches(false)
  local to = FuzzyFinderBuffer.new(branches):open_async {
    prompt_prefix = " reset " .. git.repo.head.branch .. " to > ",
  }

  if not to then
    return
  end

  -- Reset the current branch to the desired state & update reflog
  git.cli.reset.hard.args(to).call_sync()
  git.log.update_ref(git.branch.current_full_name(), to)

  notif.create(string.format("Reset '%s'", git.branch.current()), vim.log.levels.INFO)
  status.refresh(true, "reset_branch")
end)

M.delete_branch = operation("delete_branch", function()
  -- TODO: If branch is checked out:
  -- Branch gha-routes-js is checked out.  [d]etach HEAD & delete, [c]heckout origin/gha-routes-js & delete, [a]bort
  local branches = git.branch.get_all_branches()
  local selected_branch = FuzzyFinderBuffer.new(branches):open_async()
  if not selected_branch then
    return
  end

  local remote, branch_name = parse_remote_branch_name(selected_branch)

  if
    remote
    and branch_name
    and input.get_confirmation(
      "Delete remote branch '" .. remote .. "/" .. branch_name .. "'?",
      { values = { "&Yes", "&No" }, default = 2 }
    )
  then
    git.cli.push.remote(remote).delete.to(branch_name).call_sync():trim()
    notif.create(string.format("Deleted remote branch '%s/%s'", remote, branch_name), vim.log.levels.INFO)
  elseif branch_name then
    if git.branch.is_unmerged(branch_name) then
      if
        input.get_confirmation(
          "'" .. branch_name .. "' contains unmerged commits! Are you sure you want to delete it?",
          { values = { "&Yes", "&No" }, default = 2 }
        )
      then
        git.cli.branch.delete.force.name(branch_name).call_sync()
        notif.create(string.format("Deleted branch '%s'", branch_name), vim.log.levels.INFO)
      end
    else
      git.cli.branch.delete.name(branch_name).call_sync()
      notif.create(string.format("Deleted branch '%s'", branch_name), vim.log.levels.INFO)
    end
  end

  status.refresh(true, "delete_branch")
end)

return M
