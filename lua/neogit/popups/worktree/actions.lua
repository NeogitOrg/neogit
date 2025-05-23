local M = {}

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local status = require("neogit.buffers.status")
local notification = require("neogit.lib.notification")
local event = require("neogit.lib.event")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

---@param prompt string
---@param branch string?
---@return string|nil
local function get_path(prompt, branch)
  local path = input.get_user_input(prompt, {
    completion = "dir",
    prepend = vim.fs.normalize(vim.uv.cwd() .. "/..") .. "/",
  })

  if path then
    if branch and vim.uv.fs_stat(path) then
      return vim.fs.joinpath(path, branch)
    else
      return path
    end
  else
    return nil
  end
end

---@param old_cwd string?
---@param new_cwd string
---@return table
local function autocmd_helpers(old_cwd, new_cwd)
  return {
    old_cwd = old_cwd,
    new_cwd = new_cwd,
    ---@param filename string the file you want to copy
    ---@param callback function? callback to run if copy was successful
    copy_if_present = function(filename, callback)
      assert(old_cwd, "couldn't resolve old cwd")

      local source = vim.fs.joinpath(old_cwd, filename)
      local destination = vim.fs.joinpath(new_cwd, filename)

      if vim.uv.fs_stat(source) and not vim.uv.fs_stat(destination) then
        local ok = vim.uv.fs_copyfile(source, destination)
        if ok and type(callback) == "function" then
          callback()
        end
      end
    end,
  }
end

---@param prompt string
---@return string|nil
local function get_ref(prompt)
  local options = util.merge(git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())
  return FuzzyFinderBuffer.new(options):open_async { prompt_prefix = prompt }
end

function M.checkout_worktree()
  local selected = get_ref("checkout")
  if not selected then
    return
  end

  local path = get_path(("Checkout '%s' in new worktree"):format(selected), selected)
  if not path then
    return
  end

  local success, err = git.worktree.add(selected, path)
  if success then
    local cwd = vim.uv.cwd()
    notification.info("Added worktree")

    if status.is_open() then
      status.instance():chdir(path)
    end

    event.send("WorktreeCreate", autocmd_helpers(cwd, path))
  else
    notification.error(err)
  end
end

function M.create_worktree()
  local path = get_path("Create worktree")
  if not path then
    return
  end

  local selected = get_ref("Create and checkout branch starting at")
  if not selected then
    return
  end

  local name = input.get_user_input("Create branch", { strip_spaces = true })
  if not name then
    return
  end

  if git.branch.create(name, selected) then
    local success, err = git.worktree.add(name, path)
    if success then
      local cwd = vim.uv.cwd()
      notification.info("Added worktree")

      if status.is_open() then
        status.instance():chdir(path)
      end

      event.send("WorktreeCreate", autocmd_helpers(cwd, path))
    else
      notification.error(err)
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
    local main = git.worktree.main() -- A bare repo has no main, so check
    if change_dir and status.is_open() and main then
      status.instance():chdir(main.path)
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
  local options = vim
    .iter(git.worktree.list())
    :map(function(w)
      return w.path
    end)
    :filter(function(path)
      return path ~= vim.uv.cwd()
    end)
    :totable()

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
