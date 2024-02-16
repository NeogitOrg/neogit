local util = require("neogit.lib.util")
local M = {}

-- .git/sequencer/todo does not exist when there is only one commit left.
--
-- And CHERRY_PICK_HEAD does not exist when a conflict happens while picking a series of commits with --no-commit.
-- And REVERT_HEAD does not exist when a conflict happens while reverting a series of commits with --no-commit.
--
function M.pick_or_revert_in_progress()
  local git = require("neogit.lib.git")
  local pick_or_revert_todo = false

  for _, item in ipairs(git.repo.sequencer.items) do
    if item.action == "pick" or item.action == "revert" then
      pick_or_revert_todo = true
      break
    end
  end

  return git.repo.sequencer.head or pick_or_revert_todo
end

function M.update_sequencer_status(state)
  local git = require("neogit.lib.git")
  state.sequencer = { items = {}, head = nil, head_oid = nil }

  local revert_head = git.repo:git_path("REVERT_HEAD")
  local cherry_head = git.repo:git_path("CHERRY_PICK_HEAD")

  if cherry_head:exists() then
    state.sequencer.head = "CHERRY_PICK_HEAD"
    state.sequencer.head_oid = vim.trim(git.repo:git_path("CHERRY_PICK_HEAD"):read())
    state.sequencer.cherry_pick = true
  elseif revert_head:exists() then
    state.sequencer.head = "REVERT_HEAD"
    state.sequencer.head_oid = vim.trim(git.repo:git_path("REVERT_HEAD"):read())
    state.sequencer.revert = true
  end

  local todo = git.repo:git_path("sequencer/todo")
  if todo:exists() then
    for line in todo:iter() do
      if line:match("^[^#]") and line ~= "" then
        table.insert(state.sequencer.items, {
          action = line:match("^(%w+) "),
          oid = line:match("^%w+ (%x+)"),
          subject = line:match("^%w+ %x+ (.+)$"),
        })
      end
    end
  end

  state.sequencer.items = util.reverse(state.sequencer.items)

  -- TODO: Figure out the logic behind onto/gone/work
  local orig = git.repo:git_path("ORIG_HEAD")
  if state.sequencer.head_oid and orig:exists() then
    local orig_head = vim.trim(orig:read())
    table.insert(
      state.sequencer.items,
      {
        action = "work",
        oid = orig_head,
        subject = git.log.message(orig_head)
      }
    )

    table.insert(
      state.sequencer.items,
      {
        action = "onto",
        oid = state.sequencer.head_oid,
        subject = git.log.message(state.sequencer.head_oid)
      }
    )
  end
end

M.register = function(meta)
  meta.update_sequencer_status = M.update_sequencer_status
end

return M
