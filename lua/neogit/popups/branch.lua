local M = {}
local status = require("neogit.status")
local cli = require("neogit.lib.git.cli")
local popup = require("neogit.lib.popup")
local branch = require("neogit.lib.git.branch")
local git = require("neogit.lib.git")
local operation = require("neogit.operations")
local input = require("neogit.lib.input")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

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
    return nil, nil
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
      callback = function(popup, c)
        print("TODO - open branch picker")
      end,
    })
    :config_if(branch.current(), "m", "branch." .. (branch.current() or "") .. ".remote", { passive = true })
    :config_if(branch.current(), "r", "branch." .. (branch.current() or "") .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. git.config.get("pull.rebase").value, value = "" },
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
        FuzzyFinderBuffer.new(format_branches(branch.get_all_branches()), function(selected_branch)
          cli.checkout.branch(selected_branch).call_sync():trim()
          status.dispatch_refresh(true)
        end):open()
      end)
    )
    :action(
      "l",
      "local branch",
      operation("checkout_local-branch", function()
        FuzzyFinderBuffer.new(branch.get_local_branches(), function(selected_branch)
          cli.checkout.branch(selected_branch).call_sync():trim()
          status.dispatch_refresh(true)
        end):open()
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
    :action("C", "configure...") -- https://magit.vc/manual/2.11.0/magit/The-Branch-Config-Popup.html
    :action(
      "m",
      "rename",
      operation("rename_branch", function()
        local current_branch = branch.current()
        local branches = branch.get_local_branches()
        if current_branch then
          table.insert(branches, 1, current_branch)
        end

        FuzzyFinderBuffer.new(branches, function(selected_branch)
          local new_name = input.get_user_input("new branch name > ")
          if not new_name or new_name == "" then
            return
          end

          new_name, _ = new_name:gsub("%s", "-")
          cli.branch.move.args(selected_branch, new_name).call_sync():trim()
          status.dispatch_refresh(true)
        end):open()
      end)
    )
    :action("X", "reset", false)
    -- :action(
    --   "d",
    --   "delete local branch",
    --   operation("delete_branch", function()
    --     local branches = branch.get_local_branches()
    --
    --     BranchSelectViewBuffer.new(branches, function(selected_branch)
    --       cli.branch.delete.name(selected_branch).call_sync():trim()
    --       status.dispatch_refresh(true)
    --     end):open()
    --   end)
    -- )
    -- :action(
    --   "D",
    --   "delete local branch and remote",
    --   operation("delete_branch", function()
    --     local branches = format_branches(branch.get_remote_branches())
    --
    --     BranchSelectViewBuffer.new(branches, function(selected_branch)
    --       if selected_branch == "" then
    --         return
    --       end
    --
    --       local remote, branch_name = parse_remote_branch_name(selected_branch)
    --       if not remote or not branch_name then
    --         return
    --       end
    --
    --       cli.branch.delete.name(branch_name).call_sync():trim()
    --       cli.push.remote(remote).delete.to(branch_name).call_sync():trim()
    --       status.dispatch_refresh(true)
    --     end):open()
    --   end)
    -- )
    :action(
      "D",
      "delete",
      operation("delete_branch", function()
        local branches = format_branches(branch.get_remote_branches())
        FuzzyFinderBuffer.new(branches, function(selected_branch)
          local remote, branch_name = parse_remote_branch_name(selected_branch)
          if not branch_name then
            return
          end

          cli.branch.delete.name(branch_name).call_sync():trim()

          local delete_remote =
            input.get_confirmation("Delete remote?", { values = { "&Yes", "&No" }, default = 2 })

          if remote and delete_remote then
            cli.push.remote(remote).delete.to(branch_name).call_sync():trim()
          end

          status.dispatch_refresh(true)
        end):open()
      end)
    )
    :build()

  p:show()

  return p
end

return M
