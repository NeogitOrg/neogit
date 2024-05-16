local M = {}

local git = require("neogit.lib.git")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")
local operation = require("neogit.operations")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local BranchConfigPopup = require("neogit.popups.branch_config")

local function fire_branch_event(pattern, data)
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false, data = data })
end

local function spin_off_branch(checkout)
  if git.status.is_dirty() and not checkout then
    notification.info("Staying on HEAD due to uncommitted changes")
    checkout = true
  end

  local name =
    input.get_user_input(("%s branch"):format(checkout and "Spin-off" or "Spin-out"), { strip_spaces = true })
  if not name then
    return
  end

  git.branch.create(name)

  local current_branch_name = git.branch.current_full_name()

  if checkout then
    git.cli.checkout.branch(name).call()
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

---@param popup PopupData
---@param prompt string
---@param checkout boolean
---@return string|nil
---@return string|nil
local function create_branch(popup, prompt, checkout)
  -- stylua: ignore
  local options = util.deduplicate(util.merge(
    { popup.state.env.commits[1] },
    { git.branch.current() or "HEAD" },
    git.refs.list_branches(),
    git.refs.list_tags(),
    git.refs.heads()
  ))

  local base_branch = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = prompt }
  if not base_branch then
    return
  end

  local name = input.get_user_input("Create branch", { strip_spaces = true })
  if not name then
    return
  end

  git.branch.create(name, base_branch)
  fire_branch_event("NeogitBranchCreate", { branch_name = name, base = base_branch })

  if checkout then
    git.branch.checkout(name, popup:get_arguments())
    fire_branch_event("NeogitBranchCheckout", { branch_name = name })
  end
end

M.spin_off_branch = operation("spin_off_branch", function()
  spin_off_branch(true)
end)

M.spin_out_branch = operation("spin_out_branch", function()
  spin_off_branch(false)
end)

M.checkout_branch_revision = operation("checkout_branch_revision", function(popup)
  local options =
    util.merge(popup.state.env.commits, git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())
  local selected_branch = FuzzyFinderBuffer.new(options):open_async()
  if not selected_branch then
    return
  end

  git.cli.checkout.branch(selected_branch).arg_list(popup:get_arguments()).call_sync()
  fire_branch_event("NeogitBranchCheckout", { branch_name = selected_branch })
end)

M.checkout_local_branch = operation("checkout_local_branch", function(popup)
  local local_branches = git.refs.list_local_branches()
  local remote_branches = util.filter_map(git.refs.list_remote_branches(), function(name)
    local branch_name = name:match([[%/(.*)$]])
    -- Remove remote branches that have a local branch by the same name
    if branch_name and not vim.tbl_contains(local_branches, branch_name) then
      return name
    end
  end)

  local target = FuzzyFinderBuffer.new(util.merge(local_branches, remote_branches)):open_async {
    prompt_prefix = "branch",
  }

  if target then
    if vim.tbl_contains(remote_branches, target) then
      git.branch.track(target, popup:get_arguments())
    elseif target then
      git.branch.checkout(target, popup:get_arguments())
    end
    fire_branch_event("NeogitBranchCheckout", { branch_name = target })
  end
end)

M.checkout_recent_branch = operation("checkout_recent_branch", function(popup)
  local selected_branch = FuzzyFinderBuffer.new(git.branch.get_recent_local_branches()):open_async()
  if not selected_branch then
    return
  end

  git.branch.checkout(selected_branch, popup:get_arguments())
  fire_branch_event("NeogitBranchCheckout", { branch_name = selected_branch })
end)

M.checkout_create_branch = operation("checkout_create_branch", function(popup)
  create_branch(popup, "Create and checkout branch starting at", true)
end)

M.create_branch = operation("create_branch", function(popup)
  create_branch(popup, "Create branch starting at", false)
end)

M.configure_branch = operation("configure_branch", function()
  local branch_name = FuzzyFinderBuffer.new(git.refs.list_local_branches()):open_async()
  if not branch_name then
    return
  end

  BranchConfigPopup.create(branch_name)
end)

M.rename_branch = operation("rename_branch", function()
  local selected_branch = FuzzyFinderBuffer.new(git.refs.list_local_branches()):open_async()
  if not selected_branch then
    return
  end

  local new_name = input.get_user_input(("Rename '%s' to"):format(selected_branch), { strip_spaces = true })
  if not new_name then
    return
  end

  git.cli.branch.move.args(selected_branch, new_name).call()

  notification.info(string.format("Renamed '%s' to '%s'", selected_branch, new_name))
  fire_branch_event("NeogitBranchRename", { branch_name = selected_branch, new_name = new_name })
end)

M.reset_branch = operation("reset_branch", function(popup)
  if git.status.is_dirty() then
    if not input.get_permission("Uncommitted changes will be lost. Proceed?") then
      return
    end
  end

  local relatives = util.compact {
    git.branch.pushRemote_ref(),
    git.branch.upstream(),
  }

  local options = util.deduplicate(
    util.merge(
      popup.state.env.commits or {},
      relatives,
      git.refs.list_branches(),
      git.refs.list_tags(),
      git.stash.list_refs(),
      git.refs.heads()
    )
  )
  local current = git.branch.current()
  local to = FuzzyFinderBuffer.new(options):open_async {
    prompt_prefix = string.format("reset %s to", current),
  }

  if not to then
    return
  end

  -- Reset the current branch to the desired state & update reflog
  git.cli.reset.hard.args(to).call_sync()
  git.log.update_ref(git.branch.current_full_name(), to)

  notification.info(string.format("Reset '%s' to '%s'", current, to))
  fire_branch_event("NeogitBranchReset", { branch_name = current, resetting_to = to })
end)

M.delete_branch = operation("delete_branch", function()
  local branches = git.refs.list_branches()
  local selected_branch = FuzzyFinderBuffer.new(branches):open_async()
  if not selected_branch then
    return
  end

  local remote, branch_name = git.branch.parse_remote_branch(selected_branch)
  local success = false

  if
    remote
    and branch_name
    and input.get_permission(("Delete remote branch '%s/%s'?"):format(remote, branch_name))
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
    fire_branch_event("NeogitBranchDelete", { branch_name = branch_name })
  end
end)

M.open_pull_request = operation("open_pull_request", function()
  local template
  local url = git.remote.get_url(git.branch.upstream_remote())[1]

  for s, v in pairs(config.values.git_services) do
    if url:match(util.pattern_escape(s)) then
      template = v
      break
    end
  end

  if template then
    if vim.ui.open then
      local format_values = git.remote.parse(url)
      format_values["branch_name"] = git.branch.current()

      vim.ui.open(util.format(template, format_values))
    else
      notification.warn("Requires Neovim 0.10")
    end
  else
    notification.warn("Pull request URL template not found for this branch's upstream")
  end
end)

return M
