local M = {}

local a = require("plenary.async")
local logger = require("neogit.logger")
local Path = require("plenary.path")

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
  local sequencer = { items = {}, head = nil }

  local revert_head = Path.new(state.git_root .. "/.git/REVERT_HEAD")
  local cherry_head = Path.new(state.git_root .. "/.git/CHERRY_PICK_HEAD")

  if cherry_head:exists() then
    sequencer.head = "CHERRY_PICK_HEAD"
    sequencer.cherry_pick = true
  elseif revert_head:exists() then
    sequencer.head = "REVERT_HEAD"
    sequencer.revert = true
  end

  local todo = Path.new(state.git_root .. "/.git/sequencer/todo")
  if todo:exists() then
    for line in todo:iter() do
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
