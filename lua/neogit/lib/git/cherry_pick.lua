local logger = require("neogit.logger")
local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")

local M = {}

local a = require("plenary.async")

function M.pick(commits, args)
  a.util.scheduler()

  local result = cli["cherry-pick"].arg_list({ unpack(args), unpack(commits) }).call()
  if result.code ~= 0 then
    notif.create("Cherry Pick failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
  end
end

function M.apply(commits, args)
  a.util.scheduler()

  local result = cli["cherry-pick"].no_commit.arg_list({ unpack(args), unpack(commits) }).call()
  if result.code ~= 0 then
    notif.create("Cherry Pick failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
  end
end

function M.continue()
  cli["cherry-pick"].continue.call_sync()
end

function M.skip()
  cli["cherry-pick"].skip.call_sync()
end

function M.abort()
  cli["cherry-pick"].abort.call_sync()
end

local uv = require("neogit.lib.uv")
function M.update_cherry_pick_status(state)
  local cli = require("neogit.lib.git.cli")
  local root = cli.git_root()
  if root == "" then
    return
  end

  local cherry_pick = {
    items = {},
    head = nil,
  }

  local _, stat_revert_head = a.uv.fs_stat(root .. "/.git/REVERT_HEAD")
  local _, stat_cherry_pick_head = a.uv.fs_stat(root .. "/.git/CHERRY_PICK_HEAD")

  if stat_cherry_pick_head then
    cherry_pick.head = "CHERRY_PICK_HEAD"
  elseif stat_revert_head then
    cherry_pick.head = "REVERT_HEAD"
  end

  local todo_file = root .. "/.git/sequencer/todo"
  local _, stat_todo = a.uv.fs_stat(todo_file)

  if stat_todo then
    local err, todo = uv.read_file(todo_file)
    if not todo then
      logger.error("Failed to read cherry-pick sequencer/todo: " .. err)
      return
    end

    local _, todos = uv.read_file(todo_file)

    -- we need \r? to support windows
    for line in (todos or ""):gmatch("[^\r\n]+") do
      if not line:match("^#") then
        table.insert(cherry_pick.items, { name = line })
      end
    end
  end

  state.cherry_pick = cherry_pick
end

M.register = function(meta)
  meta.update_cherry_pick_status = M.update_cherry_pick_status
end

return M
