local M = {}

local git = require("neogit.lib.git")
local a = require("plenary.async")
local util = require("neogit.lib.util")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

function M.remotes_for_config()
  local remotes = {
    { display = "", value = "" },
  }

  for _, name in ipairs(git.remote.list()) do
    table.insert(remotes, { display = name, value = name })
  end

  return remotes
end

function M.merge_config(branch)
  local local_branches = git.branch.get_local_branches()
  local remote_branches = git.branch.get_remote_branches()
  local branches = util.merge(local_branches, remote_branches)

  return a.void(function(popup, c)
    local target = FuzzyFinderBuffer.new(branches):open_sync { prompt_prefix = "Upstream: " }
    if not target then
      return
    end

    local merge_value, remote_value
    if target:match([[/]]) then
      local target_remote, target_branch = unpack(vim.split(target, [[/]]))
      merge_value = "refs/heads/" .. target_branch
      remote_value = target_remote
    else
      merge_value = "refs/heads/" .. target
      remote_value = "."
    end

    git.config.set("branch." .. branch .. ".merge", merge_value)
    git.config.set("branch." .. branch .. ".remote", remote_value)

    c.value = merge_value
    popup:repaint_config()
  end)
end

return M
