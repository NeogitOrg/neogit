local git = require("neogit.lib.git")

---@class NeogitGitSequencer
local M = {}

-- .git/sequencer/todo does not exist when there is only one commit left.
--
-- And CHERRY_PICK_HEAD does not exist when a conflict happens while picking a series of commits with --no-commit.
-- And REVERT_HEAD does not exist when a conflict happens while reverting a series of commits with --no-commit.
--
---@return boolean
function M.pick_or_revert_in_progress()
  local pick_or_revert_todo = false

  for _, item in ipairs(git.repo.state.sequencer.items) do
    if item.action == "pick" or item.action == "revert" then
      pick_or_revert_todo = true
      break
    end
  end

  return git.repo.state.sequencer.head ~= nil or pick_or_revert_todo
end

---@class SequencerItem
---@field action string
---@field oid string
---@field abbreviated_commit string
---@field subject string

function M.update_sequencer_status(state)
  state.sequencer = { items = {}, head = nil, head_oid = nil, revert = false, cherry_pick = false }

  local revert_head = git.repo:worktree_git_path("REVERT_HEAD")
  local cherry_head = git.repo:worktree_git_path("CHERRY_PICK_HEAD")

  if cherry_head:exists() then
    state.sequencer.head = "CHERRY_PICK_HEAD"
    state.sequencer.head_oid = vim.trim(git.repo:worktree_git_path("CHERRY_PICK_HEAD"):read())
    state.sequencer.cherry_pick = true
  elseif revert_head:exists() then
    state.sequencer.head = "REVERT_HEAD"
    state.sequencer.head_oid = vim.trim(git.repo:worktree_git_path("REVERT_HEAD"):read())
    state.sequencer.revert = true
  end

  local HEAD_oid = git.rev_parse.oid("HEAD")
  if HEAD_oid then
    table.insert(state.sequencer.items, {
      action = "onto",
      oid = HEAD_oid,
      abbreviated_commit = HEAD_oid:sub(1, git.log.abbreviated_size()),
      subject = git.log.message(HEAD_oid),
    })
  end

  local todo = git.repo:worktree_git_path("sequencer/todo")
  if todo:exists() then
    for line in todo:iter() do
      if line:match("^[^#]") and line ~= "" then
        local oid = line:match("^%w+ (%x+)")
        table.insert(state.sequencer.items, {
          action = line:match("^(%w+) "),
          oid = oid,
          abbreviated_commit = oid:sub(1, git.log.abbreviated_size()),
          subject = line:match("^%w+ %x+ (.+)$"),
        })
      end
    end
  elseif state.sequencer.cherry_pick or state.sequencer.revert then
    table.insert(state.sequencer.items, {
      action = "join",
      oid = state.sequencer.head_oid,
      abbreviated_commit = string.sub(state.sequencer.head_oid, 1, git.log.abbreviated_size()),
      subject = git.log.message(state.sequencer.head_oid),
    })
  end
end

M.register = function(meta)
  meta.update_sequencer_status = M.update_sequencer_status
end

return M
