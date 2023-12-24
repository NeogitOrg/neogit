local M = {}

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local status = require("neogit.status")
local notification = require("neogit.lib.notification")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local Path = require("plenary.path")

function M.worktree()
  local options = util.merge(git.branch.get_all_branches(), git.tag.list(), git.refs.heads())
  local selected = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "checkout" }
  if not selected then
    return
  end

  local path = input.get_user_input(("Checkout %s in new worktree: "):format(selected), nil, "dir")
  local abs_path = Path.new(path):absolute()

  if git.worktree.add(selected, abs_path) then
    notification.info("Added worktree")
    status.chdir(abs_path)
  end
end

function M.move()
  local options = vim.tbl_map(function(w)
    return w.path
  end, git.worktree.list { include_main = false })

  local selected = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "move worktree" }
  if not selected then
    return
  end

  local path = input.get_user_input("Move worktree to: ", nil, "dir")
  local abs_path = Path.new(path):absolute()

  if git.worktree.move(selected, abs_path) then
    notification.info(("Moved worktree to %s"):format(abs_path))
    -- Only CD if moving the currently checked-out worktree
    -- if Path.new(vim.loop.cwd()):absolute() == abs_path then
    --   status.chdir(abs_path)
    -- end
  end
end

function M.delete()
  local options = vim.tbl_map(function(w)
    return w.path
  end, git.worktree.list { include_main = false })

  local selected = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "delete worktree" }
  if not selected then
    return
  end

  -- CD back to MAIN if deleting the currently checked-out worktree
  -- if Path.new(vim.loop.cwd()):absolute() == abs_path then
  --   status.chdir(abs_path)
  -- end
  --
  if input.get_confirmation("Remove worktree?") then
    -- This might produce some error messages that need to get suppressed
    if git.worktree.remove(selected) then
      notification.info("Worktree removed")
    else
      if input.get_confirmation("Worktree has untracked or modified files. Remove anyways?") then
        if git.worktree.remove(selected, { "--force" }) then
          notification.info("Worktree removed")
        end
      end
    end
  end
end

function M.visit()
  local options = vim.tbl_map(function(w)
    return w.path
  end, git.worktree.list())

  local selected = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "visit worktree" }
  if selected then
    status.chdir(selected)
  end
end

return M
