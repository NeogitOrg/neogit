local M = {}

local meta = {
  __index = {}
}

local modules = { 'status', 'diff', 'stash', 'pull', 'push', 'log' }
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
      items = {}
    },
    unstaged = {
      items = {}
    },
    staged = {
      items = {}
    },
    stashes = {
      items = {}
    },
    unpulled = {
      items = {}
    },
    unmerged = {
      items = {}
    },
    recent = {
      items = {}
    },
  }

  return setmetatable(cache, meta)
end

return M
