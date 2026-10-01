local git = require("neogit.lib.git")

---@class NeogitGitUndo
local M = {}

-- We tag the reflog message of every undo/redo we perform so we can walk back
-- through the reflog later and tell our own entries apart from regular ones.
-- This keeps the feature stateless: closing and reopening neogit doesn't lose
-- your place in the undo stack.
local UNDO_TAG = "[neogit: undo]"
local REDO_TAG = "[neogit: redo]"

---@class NeogitReflogMove
---@field old string oid HEAD pointed at before the entry
---@field subject string reflog subject line

---HEAD's reflog as a list of moves, newest first. Each move knows the oid HEAD
---sat on _before_ the entry, which is exactly what we reset back to when undoing.
---@return NeogitReflogMove[]
local function reflog()
  local lines = git.cli.reflog.show
    .format("%gs%x1f%H")
    .args("HEAD", "--")
    .call({ hidden = true, ignore_error = true }).stdout

  local moves = {}
  for i, line in ipairs(lines) do
    local subject = line:match("^(.-)\31")
    local old = lines[i + 1] and lines[i + 1]:match("\31(%x+)$")
    if subject and old then
      table.insert(moves, { old = old, subject = subject })
    end
  end

  return moves
end

---Moves HEAD to `target`, recording the move in the reflog tagged with `tag` so
---we can recognise it on a later undo/redo.
---@param target string oid to move HEAD to
---@param tag string reflog tag to attach
---@return boolean
local function move_head(target, tag)
  local result = git.cli.reset.soft.args(target).env({ GIT_REFLOG_ACTION = tag }).call { ignore_error = true }

  return result:success()
end

---Undo and redo lean entirely on the reflog, which doesn't carry enough
---information to safely step around a half-finished rebase or merge.
---@return boolean
local function busy()
  return git.rebase.in_progress() or git.merge.in_progress()
end

---Steps HEAD one entry back through the reflog.
---@return boolean success
---@return string? message
function M.undo()
  if busy() then
    return false, "Can't undo while a rebase or merge is in progress"
  end

  for _, move in ipairs(reflog()) do
    -- Skip our own undo entries so repeated presses keep walking backwards
    -- rather than toggling against the last undo. A redo entry is fair game:
    -- undoing it just steps back to before the redo.
    if not move.subject:find(UNDO_TAG, 1, true) then
      return move_head(move.old, UNDO_TAG), nil
    end
  end

  return false, "Nothing to undo"
end

---Steps HEAD one entry forward, replaying the last thing that was undone.
---@return boolean success
---@return string? message
function M.redo()
  if busy() then
    return false, "Can't redo while a rebase or merge is in progress"
  end

  -- Only the newest entry can be redone, and only if it was an undo: we move
  -- HEAD back to where that undo took us from.
  local last = reflog()[1]
  if last and last.subject:find(UNDO_TAG, 1, true) then
    return move_head(last.old, REDO_TAG), nil
  end

  return false, "Nothing to redo"
end

return M
