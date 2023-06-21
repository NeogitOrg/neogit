local M = {}

local a = require("plenary.async")
local cli = require("neogit.lib.git.cli")
local logger = require("neogit.logger")
local uv = require("neogit.lib.uv")

-- .git/sequencer/todo does not exist when there is only one commit left.
--
-- And CHERRY_PICK_HEAD does not exist when a conflict happens while picking a series of commits with --no-commit.
-- And REVERT_HEAD does not exist when a conflict happens while reverting a series of commits with --no-commit.
--
function M.pick_or_revert_in_progress()
  local git = require("neogit.lib.git")
  local pick_or_revert_todo = false

  for _, item in ipairs(git.repo.sequencer.items) do
    if item.name:match("^pick") or item.name:match("^revert") then
      pick_or_revert_todo = true
      break
    end
  end

  return git.repo.sequencer.head or pick_or_revert_todo
end

function M.update_sequencer_status(state)
  local root = cli.git_root()
  if root == "" then
    return
  end

  local sequencer = { items = {}, head = nil }

  local _, stat_revert_head = a.uv.fs_stat(root .. "/.git/REVERT_HEAD")
  local _, stat_cherry_pick_head = a.uv.fs_stat(root .. "/.git/CHERRY_PICK_HEAD")

  if stat_cherry_pick_head then
    sequencer.head = "CHERRY_PICK_HEAD"
    sequencer.cherry_pick = true
  elseif stat_revert_head then
    sequencer.head = "REVERT_HEAD"
    sequencer.revert = true
  end

  local todo_file = root .. "/.git/sequencer/todo"
  local _, stat_todo = a.uv.fs_stat(todo_file)

  if stat_todo then
    local err, todo = uv.read_file(todo_file)
    if not todo then
      logger.error("[sequencer] Failed to read .git/sequencer/todo: " .. err)
      return
    end

    local _, todos = uv.read_file(todo_file)

    -- we need \r? to support windows
    for line in (todos or ""):gmatch("[^\r\n]+") do
      if not line:match("^#") then
        table.insert(sequencer.items, { name = line })
      end
    end
  end

  state.sequencer = sequencer
end

M.register = function(meta)
  meta.update_sequencer_status = M.update_sequencer_status
end

return M
