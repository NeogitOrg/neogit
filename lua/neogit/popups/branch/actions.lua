local M = {}

local git = require("neogit.lib.git")
local config = require("neogit.config")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")
local a = require("plenary.async")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local BranchConfigPopup = require("neogit.popups.branch_config")

local function fire_branch_event(pattern, data)
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false, data = data })
end

local function fetch_remote_branch(target)
  local remote, branch = git.branch.parse_remote_branch(target)
  if remote then
    notification.info("Fetching from " .. remote .. "/" .. branch)
    git.fetch.fetch(remote, branch)
    fire_branch_event("NeogitFetchComplete", { branch = branch, remote = remote })
  end
end

local function checkout_branch(target, args)
  local result = git.branch.checkout(target, args)
  if result.code > 0 then
    notification.error(table.concat(result.stderr, "\n"))
    return
  end

  fire_branch_event("NeogitBranchCheckout", { branch_name = target })

  if config.values.fetch_after_checkout then
    a.void(function()
      local pushRemote = git.branch.pushRemote_ref(target)
      local upstream = git.branch.upstream(target)

      if upstream then
        fetch_remote_branch(upstream)
      end

      if pushRemote and pushRemote ~= upstream then
        fetch_remote_branch(pushRemote)
      end
    end)()
  end
end

local function get_branch_name_user_input(prompt, default)
  default = default or config.values.initial_branch_name
  return input.get_user_input(prompt, { strip_spaces = true, default = default })
end

---@param checkout boolean
local function spin_off_branch(checkout)
  if git.status.is_dirty() and not checkout then
    notification.info("Staying on HEAD due to uncommitted changes")
    checkout = true
  end

  local name = get_branch_name_user_input(("%s branch"):format(checkout and "Spin-off" or "Spin-out"))
  if not name then
    return
  end

  if not git.branch.create(name) then
    notification.warn("Branch " .. name .. " already exists.")
    return
  end

  fire_branch_event("NeogitBranchCreate", { branch_name = name })

  local current_branch_name = git.branch.current_full_name()

  if checkout then
    git.cli.checkout.branch(name).call()
    fire_branch_event("NeogitBranchCheckout", { branch_name = name })
  end

  local upstream = git.branch.upstream()
  if upstream then
    if checkout then
      assert(current_branch_name, "No current branch")
      git.log.update_ref(current_branch_name, upstream)
    else
      git.cli.reset.hard.args(upstream).call()
      fire_branch_event("NeogitReset", { commit = name, mode = "hard" })
    end
  end
end

---@param popup PopupData
---@param prompt string
---@param checkout boolean
---@param name? string
---@return string|nil
---@return string|nil
local function create_branch(popup, prompt, checkout, name)
  -- stylua: ignore
  local options = util.deduplicate(util.merge(
    { popup.state.env.ref_name },
    { popup.state.env.commits and popup.state.env.commits[1] },
    { git.branch.current() or "HEAD" },
    git.refs.list_branches(),
    git.refs.list_tags(),
    git.refs.heads()
  ))

  local base_branch = FuzzyFinderBuffer.new(options)
    :open_async { prompt_prefix = prompt, refocus_status = false }
  if not base_branch then
    return
  end

  -- If the base branch is a remote, prepopulate the branch name
  local suggested_branch_name
  for _, remote in ipairs(git.remote.list()) do
    local pattern = ("^%s/(.*)"):format(remote)
    if base_branch:match(pattern) then
      suggested_branch_name = base_branch:match(pattern)
      break
    end
  end

  local name = name
    or get_branch_name_user_input(
      "Create branch",
      popup.state.env.suggested_branch_name or suggested_branch_name
    )
  if not name then
    return
  end

  git.branch.create(name, base_branch)
  fire_branch_event("NeogitBranchCreate", { branch_name = name, base = base_branch })

  if checkout then
    checkout_branch(name, popup:get_arguments())
  end
end

function M.spin_off_branch()
  spin_off_branch(true)
end

function M.spin_out_branch()
  spin_off_branch(false)
end

function M.checkout_branch_revision(popup)
  local options = util.deduplicate(
    util.merge(
      { popup.state.env.ref_name },
      popup.state.env.commits or {},
      git.refs.list_branches(),
      git.refs.list_tags(),
      git.refs.heads()
    )
  )
  local selected_branch = FuzzyFinderBuffer.new(options):open_async { refocus_status = false }
  if not selected_branch then
    return
  end

  checkout_branch(selected_branch, popup:get_arguments())
end

function M.checkout_local_branch(popup)
  local local_branches = git.refs.list_local_branches()
  local remote_branches = util.filter_map(git.refs.list_remote_branches(), function(name)
    local branch_name = name:match([[%/(.*)$]])
    -- Remove remote branches that have a local branch by the same name
    if branch_name and not vim.tbl_contains(local_branches, branch_name) then
      return name
    end
  end)

  local options = util.merge(local_branches, remote_branches)
  local target = FuzzyFinderBuffer.new(options):open_async {
    prompt_prefix = "branch",
    refocus_status = false,
  }

  if target then
    if vim.tbl_contains(remote_branches, target) then
      git.branch.track(target, popup:get_arguments())
      fire_branch_event("NeogitBranchCheckout", { branch_name = target })
    elseif not vim.tbl_contains(options, target) then
      target, _ = target:gsub("%s", "-")
      create_branch(popup, "Create " .. target .. " starting at", true, target)
    else
      checkout_branch(target, popup:get_arguments())
    end
  end
end

function M.checkout_recent_branch(popup)
  local selected_branch = FuzzyFinderBuffer.new(git.branch.get_recent_local_branches()):open_async()
  if not selected_branch then
    return
  end

  checkout_branch(selected_branch, popup:get_arguments())
end

function M.checkout_create_branch(popup)
  create_branch(popup, "Create and checkout branch starting at", true)
end

function M.create_branch(popup)
  create_branch(popup, "Create branch starting at", false)
end

function M.configure_branch()
  local branch_name = FuzzyFinderBuffer.new(git.refs.list_local_branches())
    :open_async { refocus_status = false }
  if not branch_name then
    return
  end

  BranchConfigPopup.create(branch_name)
end

function M.rename_branch()
  local selected_branch = FuzzyFinderBuffer.new(git.refs.list_local_branches())
    :open_async { refocus_status = false }
  if not selected_branch then
    return
  end

  local new_name = get_branch_name_user_input(("Rename '%s' to"):format(selected_branch))
  if not new_name then
    return
  end

  git.cli.branch.move.args(selected_branch, new_name).call { await = true }

  notification.info(string.format("Renamed '%s' to '%s'", selected_branch, new_name))
  fire_branch_event("NeogitBranchRename", { branch_name = selected_branch, new_name = new_name })
end

function M.reset_branch(popup)
  if not git.branch.current() then
    notification.warn("Cannot reset with detached HEAD")
    return
  end

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
  git.cli.reset.hard.args(to).call()
  local current = git.branch.current_full_name()
  assert(current, "no current branch")
  git.log.update_ref(current, to)

  notification.info(string.format("Reset '%s' to '%s'", current, to))
  fire_branch_event("NeogitBranchReset", { branch_name = current, resetting_to = to })
end

function M.delete_branch(popup)
  local options = util.deduplicate(util.merge({ popup.state.env.ref_name }, git.refs.list_branches()))
  local selected_branch = FuzzyFinderBuffer.new(options)
    :open_async { prompt_prefix = "Delete branch", refocus_status = false }
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
    success = git.cli.push.remote(remote).delete.to(branch_name).call().code == 0
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
      git.cli.checkout.detach.call()
    elseif choice == "c" then
      assert(upstream, "there should be an upstream by this point")
      git.cli.checkout.branch(upstream).call()
    else
      return
    end

    success = git.branch.delete(branch_name)
    if not success then -- Reset HEAD if unsuccessful
      git.cli.checkout.branch(branch_name).call()
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
end

function M.open_pull_request()
  local template
  local service
  local upstream = git.branch.upstream_remote()
  if not upstream then
    return
  end

  local url = git.remote.get_url(upstream)[1]

  for s, v in pairs(config.values.git_services) do
    if url:match(util.pattern_escape(s)) then
      service = s
      template = v
      break
    end
  end

  if template then
    if vim.ui.open then
      local format_values = git.remote.parse(url)
      format_values["branch_name"] = git.branch.current()

      -- azure prepends a `v3/` to the owner name but the pull request URL errors out
      -- if you include it
      if service == "azure.com" then
        local correctedOwner = string.gsub(format_values["path"], "v3/", "")
        format_values["path"] = correctedOwner
        format_values["owner"] = correctedOwner

        local remote_branches = util.map(git.refs.list_remote_branches("origin"), function(branch)
          branch = string.gsub(branch, "origin/", "")
          return branch
        end)
        local target = FuzzyFinderBuffer.new(util.merge(remote_branches)):open_async {
          prompt_prefix = "Select target branch",
        }
        format_values["target"] = target
      end

      vim.ui.open(util.format(template, format_values))
    else
      notification.warn("Requires Neovim 0.10")
    end
  else
    notification.warn("Pull request URL template not found for this branch's upstream")
  end
end

return M
