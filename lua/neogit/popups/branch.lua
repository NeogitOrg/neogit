local M = {}
local status = require("neogit.status")
local cli = require("neogit.lib.git.cli")
local popup = require("neogit.lib.popup")
local branch = require("neogit.lib.git.branch")
local operation = require("neogit.operations")
local BranchSelectViewBuffer = require("neogit.buffers.branch_select_view")
local input = require("neogit.lib.input")

local function parse_remote_branch_name(remote_name)
  local offset = remote_name:find("/")
  if not offset then
    return nil, nil
  end

  local remote = remote_name:sub(1, offset - 1)
  local branch_name = remote_name:sub(offset + 1, remote_name:len())

  return remote, branch_name
end

function M.create()
  local p = popup
    .builder()
    :name("NeogitBranchPopup")
    :action(
      "n",
      "create branch",
      operation("create_branch", function()
        branch.create()
        status.refresh(true, "create_branch")
      end)
    )
    :action(
      "b",
      "checkout branch/revision",
      operation("checkout_branch", function()
        local branches = (branch.get_all_branches())
        local branch = BranchSelectViewBuffer.new(branches):open_async()
        if not branch then
          return
        end

        cli.checkout.branch(branch).call():trim()
        status.dispatch_refresh(true)
      end)
    )
    :action(
      "d",
      "delete local branch",
      operation("delete_branch", function()
        local branches = branch.get_local_branches()
        local branch = BranchSelectViewBuffer.new(branches):open_async()
        if not branch then
          return
        end
        cli.branch.delete.name(branch).call():trim()
        status.dispatch_refresh(true)
      end)
    )
    :action(
      "D",
      "delete local branch and remote",
      operation("delete_branch", function()
        local branches = (branch.get_remote_branches())
        local branch = BranchSelectViewBuffer.new(branches):open_async()
        if not branch then
          return
        end

        local remote, branch_name = parse_remote_branch_name(branch)
        if not remote or not branch_name then
          return
        end

        cli.branch.delete.name(branch_name).call_sync():trim()
        cli.push.remote(remote).delete.to(branch_name).call():trim()
        status.dispatch_refresh(true)
      end)
    )
    :action(
      "l",
      "checkout local branch",
      operation("checkout_local-branch", function()
        local branches = branch.get_local_branches()
        local branch = BranchSelectViewBuffer.new(branches):open_async()
        if not branch then
          return
        end

        cli.checkout.branch(branch).call():trim()
        status.dispatch_refresh(true)
      end)
    )
    :action(
      "c",
      "checkout new branch",
      operation("checkout_create-branch", function()
        local branches = branch.get_all_branches(true)
        local current_branch = branch.current()
        if current_branch then
          table.insert(branches, 1, current_branch)
        end

        local branch = BranchSelectViewBuffer.new(branches):open_async()
        if not branch then
          return
        end

        local name = input.get_user_input("branch > ")
        if not name or name == "" then
          return
        end

        cli.checkout.new_branch_with_start_point(name, branch).call():trim()
        status.dispatch_refresh(true)
      end)
    )
    :action(
      "m",
      "rename branch",
      operation("rename_branch", function()
        local current_branch = branch.current()
        local branches = branch.get_local_branches()
        if current_branch then
          table.insert(branches, 1, current_branch)
        end

        local branch = BranchSelectViewBuffer.new(branches):open_async()
        if not branch then
          return
        end

        local new_name = input.get_user_input("new branch name > ")
        if not new_name or new_name == "" then
          return
        end

        cli.branch.move.args(branch, new_name).call():trim()
        status.dispatch_refresh(true)
      end)
    )
    :build()

  p:show()

  return p
end

return M
