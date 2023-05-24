local M = {}
local status = require("neogit.status")
local cli = require("neogit.lib.git.cli")
local popup = require("neogit.lib.popup")
local branch = require("neogit.lib.git.branch")
local git = require("neogit.lib.git")
local operation = require("neogit.operations")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local notif = require("neogit.lib.notification")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local BranchConfigPopup = require("neogit.popups.branch_config")

local function format_branches(list)
  local branches = {}
  for _, name in ipairs(list) do
    local name_formatted = name:match("^remotes/(.*)") or name
    if not name_formatted:match("^(.*)/HEAD") then
      table.insert(branches, name_formatted)
    end
  end
  return branches
end

local function parse_remote_branch_name(remote_name)
  local offset = remote_name:find("/")
  if not offset then
    return nil, remote_name
  end

  local remote = remote_name:sub(1, offset - 1)
  local branch_name = remote_name:sub(offset + 1, remote_name:len())

  return remote, branch_name
end

local function remotes_for_config()
  local remotes = {
    { display = "", value = "" },
  }

  for _, name in ipairs(git.remote.list()) do
    table.insert(remotes, { display = name, value = name })
  end

  return remotes
end

function M.create()
  local p = popup
    .builder()
    :name("NeogitBranchPopup")
    :switch("r", "recurse-submodules", "Recurse submodules when checking out an existing branch")
    :config_if(branch.current(), "d", "branch." .. (branch.current() or "") .. ".description")
    :config_if(branch.current(), "u", "branch." .. (branch.current() or "") .. ".merge", {
      callback = git.branch.merge_config(branch.current())
    })
    :config_if(branch.current(), "m", "branch." .. (branch.current() or "") .. ".remote", { passive = true })
    :config_if(branch.current(), "r", "branch." .. (branch.current() or "") .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. (git.config.get("pull.rebase").value or ""), value = "" },
      },
    })
    :config_if(branch.current(), "p", "branch." .. (branch.current() or "") .. ".pushRemote", {
      options = remotes_for_config(),
    })
    :group_heading("Checkout")
    :action(
      "b",
      "branch/revision",
      operation("checkout_branch", function()
        local selected_branch = FuzzyFinderBuffer.new(format_branches(branch.get_all_branches())):open_sync()
        cli.checkout.branch(selected_branch).call_sync():trim()
        status.refresh(true, "checkout_branch")
      end)
    )
    :action(
      "l",
      "local branch",
      operation("checkout_local-branch", function()
        local local_branches = branch.get_local_branches()
        local remote_branches = util.filter_map(branch.get_remote_branches(), function(name)
          if name:match([[ ]]) then -- removes stuff like 'origin/HEAD -> origin/master'
            return nil
          else
            local branch_name = name:match([[%/(.*)$]])
            -- Remove remote branches that have a local branch by the same name
            if branch_name and not vim.tbl_contains(local_branches, branch_name) then
              return name
            end
          end
        end)

        local target = FuzzyFinderBuffer.new(util.merge(local_branches, remote_branches))
          :open_sync { prompt_prefix = " branch > " }
        if target:match([[/]]) then
          cli.checkout.track(target).call_sync()
        else
          cli.checkout.branch(target).call_sync()
        end

        status.refresh(true, "branch_checkout")
      end)
    )
    :new_action_group()
    :action(
      "c",
      "new branch",
      operation("checkout_create-branch", function()
        local branches = format_branches(branch.get_all_branches(false))
        local current_branch = branch.current()
        if current_branch then
          table.insert(branches, 1, current_branch)
        end

        local name = input.get_user_input("branch > ")
        if not name or name == "" then
          return
        end
        name, _ = name:gsub("%s", "-")

        local base_branch = FuzzyFinderBuffer.new(branches):open_sync { prompt_prefix = " base branch > " }
        cli.checkout.new_branch_with_start_point(name, base_branch).call_sync():trim()
        status.refresh(true, "branch_create")
      end)
    )
    :action("s", "new spin-off") -- https://github.com/magit/magit/blob/main/lisp/magit-branch.el#L429
    :action("w", "new worktree")
    :new_action_group("Create")
    :action(
      "n",
      "new branch",
      operation("create_branch", function()
        branch.create()
        status.refresh(true, "create_branch")
      end)
    )
    :action("S", "new spin-out")
    :action("W", "new worktree")
    :new_action_group("Do")
    :action("C", "Configure...", function()
      local branch_name = FuzzyFinderBuffer.new(git.branch.get_local_branches(true)):open_sync()
      if not branch_name then
        return
      end

      BranchConfigPopup.create(branch_name)
    end)
    :action(
      "m",
      "rename",
      operation("rename_branch", function()
        local current_branch = branch.current()
        local branches = branch.get_local_branches()
        if current_branch then
          table.insert(branches, 1, current_branch)
        end

        local selected_branch = FuzzyFinderBuffer.new(branches):open_sync()
        local new_name = input.get_user_input("new branch name > ")
        if not new_name or new_name == "" then
          return
        end

        new_name, _ = new_name:gsub("%s", "-")
        cli.branch.move.args(selected_branch, new_name).call_sync():trim()
        status.refresh(true, "rename_branch")
      end)
    )
    :action("X", "reset", function()
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

      local branches = format_branches(branch.get_all_branches(false))
      local to = FuzzyFinderBuffer.new(branches):open_sync {
        prompt_prefix = " reset " .. branch.current() .. " to > ",
      }

      if not to then
        return
      end

      -- Reset the current branch to the desired state
      git.cli.reset.hard.args(to).call_sync()

      -- Update reference
      local from = git.cli["rev-parse"].symbolic_full_name.args(branch.current()).call_sync():trim().stdout[1]
      git.cli["update-ref"].message(string.format("reset: moving to %s", to)).args(from, to).call_sync()

      notif.create(string.format("Reset '%s'", branch.current()), vim.log.levels.INFO)
      status.refresh(true, "reset_branch")
    end)
    :action(
      "D",
      "delete",
      operation("delete_branch", function()
        -- TODO: If branch is checked out:
        -- Branch gha-routes-js is checked out.  [d]etach HEAD & delete, [c]heckout origin/gha-routes-js & delete, [a]bort
        local branches = format_branches(branch.get_all_branches())
        local selected_branch = FuzzyFinderBuffer.new(branches):open_sync()
        if not selected_branch then
          return
        end

        local remote, branch_name = parse_remote_branch_name(selected_branch)
        cli.branch.delete.name(branch_name).call_sync():trim()

        if remote and input.get_confirmation("Delete remote?", { values = { "&Yes", "&No" }, default = 2 }) then
          cli.push.remote(remote).delete.to(branch_name).call_sync():trim()
        end

        notif.create(string.format("Deleted branch '%s'", branch_name), vim.log.levels.INFO)
        status.refresh(true, "delete_branch")
      end)
    )
    :build()

  p:show()

  return p
end

return M
