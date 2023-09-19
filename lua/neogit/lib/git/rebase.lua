local logger = require("neogit.logger")
local client = require("neogit.client")
local notification = require("neogit.lib.notification")

local M = {}

local a = require("plenary.async")

local function rebase_command(cmd)
  local git = require("neogit.lib.git")
  cmd = cmd or git.cli.rebase
  local envs = client.get_envs_git_editor()
  return cmd.env(envs).show_popup(true):in_pty(true).call(true)
end

function M.rebase_interactive(commit, args)
  a.util.scheduler()
  local git = require("neogit.lib.git")
  local result = rebase_command(git.cli.rebase.interactive.args(commit).arg_list(args))
  if result.code ~= 0 then
    notification.error("Rebasing failed. Resolve conflicts before continuing")
  else
    notification.info("Rebased successfully")
  end
end

function M.rebase_onto(branch, args)
  a.util.scheduler()
  local git = require("neogit.lib.git")
  local result = rebase_command(git.cli.rebase.args(branch).arg_list(args))
  if result.code ~= 0 then
    notification.error("Rebasing failed. Resolve conflicts before continuing")
  else
    notification.info("Rebased onto '" .. branch .. "'")
  end
end

function M.continue()
  local git = require("neogit.lib.git")
  return rebase_command(git.cli.rebase.continue)
end

function M.skip()
  local git = require("neogit.lib.git")
  return rebase_command(git.cli.rebase.skip)
end

function M.update_rebase_status(state)
  if state.git_root == "" then
    return
  end

  state.rebase = { items = {}, head = nil, current = nil }

  local rebase_file
  local rebase_merge = state.git_path("rebase-merge")
  local rebase_apply = state.git_path("rebase-apply")

  if rebase_merge:exists() then
    rebase_file = rebase_merge
  elseif rebase_apply:exists() then
    rebase_file = rebase_apply
  end

  if rebase_file then
    local head = rebase_file:joinpath("head-name")
    if not head:exists() then
      logger.error("Failed to read rebase-merge head")
      return
    end

    state.rebase.head = head:read():match("refs/heads/([^\r\n]+)")

    local done = rebase_file:joinpath("done")
    if done:exists() then
      for line in done:iter() do
        if line:match("^[^#]") and line ~= "" then
          table.insert(state.rebase.items, { name = line, done = true })
        end
      end
    end

    local cur = state.rebase.items[#state.rebase.items]
    if cur then
      cur.done = false
      cur.stopped = true
      state.rebase.current = #state.rebase.items
    end

    local todo = rebase_file:joinpath("git-rebase-todo")
    if todo:exists() then
      for line in todo:iter() do
        if line:match("^[^#]") and line ~= "" then
          table.insert(state.rebase.items, { name = line })
        end
      end
    end
  end
end

M.register = function(meta)
  meta.update_rebase_status = M.update_rebase_status
end

return M
