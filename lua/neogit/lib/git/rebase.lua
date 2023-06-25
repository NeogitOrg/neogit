local logger = require("neogit.logger")
local client = require("neogit.client")
local notif = require("neogit.lib.notification")

local M = {}

local a = require("plenary.async")
local Path = require("plenary.path")

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
    notif.create("Rebasing failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
  else
    notif.create("Rebased successfully", vim.log.levels.INFO)
  end
  a.util.scheduler()
  local status = require("neogit.status")
  status.refresh(true, "rebase_interactive")
end

function M.rebase_onto(branch, args)
  a.util.scheduler()
  local git = require("neogit.lib.git")
  local result = rebase_command(git.cli.rebase.args(branch).arg_list(args))
  if result.code ~= 0 then
    notif.create("Rebasing failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
  else
    notif.create("Rebased onto '" .. branch .. "'", vim.log.levels.INFO)
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

  local rebase = {
    items = {},
    head = nil,
    current = nil,
  }

  local rebase_file
  local rebase_merge = Path:new(state.git_root .. "/.git/rebase-merge")
  local rebase_apply = Path:new(state.git_root .. "/.git/rebase-apply")

  if rebase_merge:exists() then
    rebase_file = rebase_merge
  elseif rebase_apply:exists() then
    rebase_file = rebase_apply
  end

  if rebase_file then
    local head = rebase_file:joinpath("/head-name")
    if not head:exists() then
      logger.error("Failed to read rebase-merge head")
      return
    end

    rebase.head = head:read():match("refs/heads/([^\r\n]+)")

    local todo = rebase_file:joinpath("/git-rebase-todo")
    local done = rebase_file:joinpath("/done")
    local current = 0
    for line in done:iter() do
      if not line:match("^#") then
        current = current + 1
        table.insert(rebase.items, { name = line, done = true })
      end
    end

    rebase.current = current

    local cur = rebase.items[#rebase.items]
    if cur then
      cur.done = false
      cur.stopped = true
    end

    for line in todo:iter() do
      if not line:match("^#") then
        table.insert(rebase.items, { name = line })
      end
    end
  end

  state.rebase = rebase
end

M.register = function(meta)
  meta.update_rebase_status = M.update_rebase_status
end

return M
