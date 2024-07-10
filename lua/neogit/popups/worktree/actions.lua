local M = {}

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local status = require("neogit.buffers.status")
local notification = require("neogit.lib.notification")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local Path = require("plenary.path")
local scan_dir = require("plenary.scandir").scan_dir

---Poor man's dired
---@return string|nil
local function get_path(prompt)
  local dir = Path.new(".")
  repeat
    local dirs = scan_dir(dir:absolute(), { depth = 1, only_dirs = true })
    local selected = FuzzyFinderBuffer.new(util.merge({ ".." }, dirs)):open_async {
      prompt_prefix = prompt,
    }

    if not selected then
      return
    end

    if vim.startswith(selected, "/") then
      dir = Path.new(selected)
    else
      dir = dir:joinpath(selected)
    end
  until not dir:exists()

  local path, _ = dir:absolute():gsub("%s", "_")
  return path
end

function M.checkout_worktree()
  local options = util.merge(git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())
  local selected = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "checkout" }
  if not selected then
    return
  end

  local path = get_path(("Checkout %s in new worktree"):format(selected))
  if not path then
    return
  end

  if git.worktree.add(selected, path) then
    notification.info("Added worktree")
    if status.is_open() then
      status.instance():chdir(path)
    end
  end
end

function M.create_worktree()
  local path = get_path("Create worktree")
  if not path then
    return
  end

  local options = util.merge(git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())
  local selected = FuzzyFinderBuffer.new(options)
    :open_async { prompt_prefix = "Create and checkout branch starting at" }
  if not selected then
    return
  end

  local name = input.get_user_input("Create branch", { strip_spaces = true })
  if not name then
    return
  end

  if git.worktree.add(selected, path, { "-b", name }) then
    notification.info("Added worktree")
    if status.is_open() then
      status.instance():chdir(path)
    end
  end
end

function M.move()
  local options = vim.tbl_map(function(w)
    return w.path
  end, git.worktree.list { include_main = false })

  if #options == 0 then
    notification.info("No worktrees present")
    return
  end

  local selected = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "move worktree" }
  if not selected then
    return
  end

  local path = get_path("Move worktree to")
  if not path then
    return
  end

  local cwd = vim.uv.cwd()
  assert(cwd, "cannot determine cwd")
  local change_dir = vim.fs.normalize(selected) == vim.fs.normalize(cwd)

  if git.worktree.move(selected, path) then
    notification.info(("Moved worktree to %s"):format(path))

    if change_dir and status.is_open() then
      status.instance():chdir(path)
    end
  end
end

function M.delete()
  local options = vim.tbl_map(function(w)
    return w.path
  end, git.worktree.list { include_main = false })

  if #options == 0 then
    notification.info("No worktrees present")
    return
  end

  local selected = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "delete worktree" }
  if not selected then
    return
  end

  local cwd = vim.uv.cwd()
  assert(cwd, "cannot determine cwd")
  local change_dir = vim.fs.normalize(selected) == vim.fs.normalize(cwd)
  local success = false

  if input.get_permission(("Remove worktree at %q?"):format(selected)) then
    if change_dir and status.is_open() then
      status.instance():chdir(git.worktree.main().path)
    end

    -- This might produce some error messages that need to get suppressed
    if git.worktree.remove(selected) then
      success = true
    else
      if input.get_permission("Worktree has untracked or modified files. Remove anyways?") then
        if git.worktree.remove(selected, { "--force" }) then
          success = true
        end
      end
    end

    if success then
      notification.info("Worktree removed")
    end
  end
end

function M.visit()
  local options = vim.tbl_map(function(w)
    return w.path
  end, git.worktree.list())

  if #options == 0 then
    notification.info("No worktrees present")
    return
  end

  local selected = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "visit worktree" }
  if selected and status.is_open() then
    status.instance():chdir(selected)
  end
end

return M
