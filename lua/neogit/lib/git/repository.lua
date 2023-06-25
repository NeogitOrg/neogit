local a = require("plenary.async")
local logger = require("neogit.logger")

local function empty_state()
  return {
    ---The cwd when this was updated.
    ---Used to generate absolute paths
    cwd = ".",
    git_root = nil,
    head = {
      branch = nil,
      commit_message = "",
    },
    upstream = {
      remote = nil,
      branch = nil,
      commit_message = "",
    },
    untracked = {
      items = {},
    },
    unstaged = {
      items = {},
    },
    staged = {
      items = {},
    },
    stashes = {
      items = {},
    },
    unpulled = {
      items = {},
    },
    unmerged = {
      items = {},
    },
    recent = {
      items = {},
    },
    rebase = {
      items = {},
      head = nil,
    },
    sequencer = {
      items = {},
      head = nil,
    },
    merge = {
      items = {},
      head = nil,
      msg = nil,
    },
  }
end

local meta = {
  __index = function(self, method)
    return self.state[method]
  end,
}

local M = {}

M.state = empty_state()
M.lib = {}

function M.reset(self)
  self.state = empty_state()
end

function M.refresh(self)
  logger.debug("[REPO]: Refreshing START")

  self.state.git_root = require("neogit.lib.git.cli").git_root()
  if self.state.git_root == "" then
    logger.debug("[REPO]: Refreshing ABORTED")
    return
  end

  self.lib.update_status(self.state)

  for name, fn in pairs(self.lib) do
    logger.debug(string.format("[REPO]: Refreshing %s", name))
    fn(self.state)
  end

  logger.debug("[REPO]: Refreshes completed")
end

if not M.initialized then
  logger.debug("[REPO]: Initializing Repository")
  M.initialized = true

  setmetatable(M, meta)

  local modules = {
    "status",
    "diff",
    "stash",
    "pull",
    "push",
    "log",
    "rebase",
    "sequencer",
    "merge",
  }

  for _, m in ipairs(modules) do
    require("neogit.lib.git." .. m).register(M.lib)
  end
end

return M
