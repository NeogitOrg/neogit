local popup = require("neogit.lib.popup")
local status = require("neogit.status")
local input = require("neogit.lib.input")
local a = require("plenary.async")

local M = {}

local function pull_from(popup, name, remote, branch)
  local pull_lib = require("neogit.lib.git.pull")
  local notif = require("neogit.lib.notification")
  notif.create(string.format("Pulling from %q", name))

  local res = pull_lib.pull_interactive(remote, branch, popup:get_arguments())

  if res and res.code == 0 then
    a.util.scheduler()
    notif.create(string.format("Pulled from %q", name))
    vim.api.nvim_exec_autocmds("User", { pattern = "NeogitPullComplete", modeline = false })
  end

  status.refresh(true, "pull_from")
end

function M.create()
  local notif = require("neogit.lib.notification")
  local git = require("neogit.lib.git")

  local p = popup
    .builder()
    :name("NeogitPullPopup")
    :switch("r", "rebase", "Rebase local commits", false)
    :action("p", "Pull from pushremote", function(popup)
      pull_from(popup, "pushremote", "origin", status.repo.head.branch)
    end)
    :action("u", "Pull from upstream", function(popup)
      local upstream = git.branch.get_upstream()

      if upstream == nil then
        require("neogit.lib.notification").create(
          string.format("No upstream set for branch %q", status.repo.head.branch),
          vim.log.levels.ERROR
        )
        return
      end
      local name = upstream.remote .. "/" .. upstream.branch
      pull_from(popup, name, upstream.remote, upstream.branch)
    end)
    :action("e", "Pull from elsewhere", function(popup)
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

      local branch =
        git.branch.prompt_for_branch(branch_options, { truncate_remote_name_from_options = true })
      if not branch then
        notif.create("Aborting pull because there is no branch")
        return
      end

      pull_from(popup, remote, remote, branch)
    end)
    :build()

  p:show()

  return p
end

return M
