local Path = require("plenary.path")
local git = require("neogit.lib.git")

local M = {} ---@class NeogitGitHooks

local hooks = {
  commit = {
    "pre-commit",
    "pre-merge-commit",
    "prepare-commit-msg",
    "commit-msg",
    "post-commit",
    "post-rewrite",
  },
  merge = {
    "pre-merge-commit",
    "commit-msg",
    "post-merge",
  },
  rebase = {
    "pre-rebase",
    "post-rewrite",
  },
  checkout = {
    "post-checkout",
  },
  push = {
    "pre-push",
  },
}

local function is_executable(mode)
  -- Extract the octal digits
  local owner = math.floor(mode / 64) % 8
  local group = math.floor(mode / 8) % 8
  local other = mode % 8

  -- Check if odd
  local owner_exec = owner % 2 == 1
  local group_exec = group % 2 == 1
  local other_exec = other % 2 == 1

  return owner_exec or group_exec or other_exec
end

function M.register(meta)
  meta.update_hooks = function(state)
    state.hooks = {}

    if not Path:new(state.git_dir):joinpath("hooks"):is_dir() then
      return
    end

    for file in vim.fs.dir(vim.fs.joinpath(state.git_dir, "hooks")) do
      if not file:match("%.sample$") then
        local path = vim.fs.joinpath(state.git_dir, "hooks", file)
        local stat = vim.uv.fs_stat(path)

        if stat and stat.mode and is_executable(stat.mode) then
          table.insert(state.hooks, file)
        end
      end
    end
  end
end

function M.exists(cmd)
  if hooks[cmd] then
    for _, hook in ipairs(hooks[cmd]) do
      if vim.tbl_contains(git.repo.state.hooks, hook) then
        return true
      end
    end
  end

  return false
end

return M
