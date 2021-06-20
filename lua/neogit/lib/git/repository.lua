local M = {}

local meta = {
  __index = {}
}

local modules = { 'status', 'diff', 'stash', 'pull', 'push' }
for _, m in ipairs(modules) do
  require('neogit.lib.git.'..m).register(meta.__index)
end

M.create = function (_path)
  local cache = {
    head = {
      branch = nil,
      commit_message = ''
    },
    upstream = {
      breanch = nil,
      commit_message = ''
    },
    untracked = {
      files = {}
    },
    unstaged = {
      files = {}
    },
    staged = {
      files = {}
    },
    stashes = {
      files = {}
    },
    unpulled = {
      files = {}
    },
    unmerged = {
      files = {}
    }
  }

  return setmetatable(cache, meta)
end

return M
