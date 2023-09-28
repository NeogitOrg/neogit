local M = {}

local git = require("neogit.lib.git")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")
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
    notification.info("Staying on HEAD due to uncommitted changes")
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
end)

M.spin_out_branch = operation("spin_out_branch", function()
  spin_off_branch(false)
end)

M.checkout_branch_revision = operation("checkout_branch_revision", function(popup)
  local options = util.merge(popup.state.env.commits, git.branch.get_all_branches())

  local selected_branch = FuzzyFinderBuffer.new(options):open_async()
  if not selected_branch then
    return
  end

  git.cli.checkout.branch(selected_branch).arg_list(popup:get_arguments()).call_sync():trim()
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

  if target then
    if vim.tbl_contains(remote_branches, target) then
      git.cli.checkout.track(target).arg_list(popup:get_arguments()).call_sync()
    elseif target then
      git.cli.checkout.branch(target).arg_list(popup:get_arguments()).call_sync()
    end
  end
end)

M.checkout_recent_branch = operation("checkout_recent_branch", function(popup)
  local selected_branch = FuzzyFinderBuffer.new(git.branch.get_recent_local_branches()):open_async()
  if not selected_branch then
    return
  end

  git.cli.checkout.branch(selected_branch).arg_list(popup:get_arguments()).call_sync():trim()
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
end)

M.create_branch = operation("create_branch", function()
  local name = input.get_user_input("branch > ")
  if not name or name == "" then
    return
  end

  name, _ = name:gsub("%s", "-")
  git.branch.create(name)
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
end)

M.reset_branch = operation("reset_branch", function()
  if git.status.is_dirty() then
    local confirmation = input.get_confirmation(
      "Uncommitted changes will be lost. Proceed?",
      { values = { "&Yes", "&No" }, default = 2 }
    )
    if not confirmation then
      return
    end
  end

  local current = git.branch.current()
  local branches = git.branch.get_all_branches(false)
  local to = FuzzyFinderBuffer.new(branches):open_async {
    prompt_prefix = string.format(" reset %s to > ", current),
  }

  if not to then
    return
  end

  -- Reset the current branch to the desired state & update reflog
  git.cli.reset.hard.args(to).call_sync()
  git.log.update_ref(git.branch.current_full_name(), to)

  notification.info(string.format("Reset '%s' to '%s'", current, to))
end)

M.delete_branch = operation("delete_branch", function()
  local branches = git.branch.get_all_branches(true)
  local selected_branch = FuzzyFinderBuffer.new(branches):open_async()
  if not selected_branch then
    return
  end

  local remote, branch_name = parse_remote_branch_name(selected_branch)
  local success = false

  if
    remote
    and branch_name
    and input.get_confirmation(
      string.format("Delete remote branch '%s/%s'?", remote, branch_name),
      { values = { "&Yes", "&No" }, default = 2 }
    )
  then
    success = git.cli.push.remote(remote).delete.to(branch_name).call_sync().code == 0
  elseif not remote and branch_name == git.branch.current() then
    local choices = {
      "&detach HEAD and delete",
      "&abort",
    }

    local upstream = git.branch.upstream()
    if upstream then
      table.insert(choices, 2, string.format("&checkout %s and delete", upstream))
    end

    local choice = input.get_choice(
      string.format("Branch '%s' is currently checked out.", branch_name),
      { values = choices, default = #choices }
    )

    if choice == "d" then
      git.cli.checkout.detach.call_sync()
    elseif choice == "c" then
      git.cli.checkout.branch(upstream).call_sync()
    else
      return
    end

    success = git.branch.delete(branch_name)
    if not success then -- Reset HEAD if unsuccessful
      git.cli.checkout.branch(branch_name).call_sync()
    end
  elseif not remote and branch_name then
    success = git.branch.delete(branch_name)
  end

  if success then
    if remote then
      notification.info(string.format("Deleted remote branch '%s/%s'", remote, branch_name))
    else
      notification.info(string.format("Deleted branch '%s'", branch_name))
    end
  end
end)

local function parse_remote_info(url)
  local repo, owner
  if url:match("^https?://") or url:match("^ssh://") then
    repo, owner, _ = unpack(util.reverse(vim.split(url, "/")))
  else
    owner, repo = unpack(vim.split(vim.split(url, ":")[2], "/"))
  end

  repo, _ = repo:gsub(".git$", "")
  return { repository = repo, owner = owner, branch_name = git.branch.current() }
end

M.open_pull_request = operation("open_pull_request", function()
  local template
  local url = git.remote.get_url(git.branch.upstream_remote())[1]
  for service, v in pairs(config.values.git_services) do
    if url:match(service) then
      template = v
      break
    end
  end

  if template then
    if vim.ui.open then
      vim.ui.open(util.format(template, parse_remote_info(url)))
    else
      notification.warn("Requires Neovim 0.10")
    end
  else
    notification.warn("Pull request URL template not found for this branch's upstream")
  end
end)

return M
