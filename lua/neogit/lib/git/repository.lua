local a = require("plenary.async")
local logger = require("neogit.logger")

-- git-status outputs files relative to the cwd.
--
-- Save the working directory to allow resolution to absolute paths since the
-- cwd may change after the status is refreshed and used, especially if using
-- rooter plugins with lsp integration
local function empty_state()
  return {
    cwd = vim.fn.getcwd(),
    git_root = require("neogit.lib.git.cli").git_root(),
    rev_toplevel = nil,
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

M.dispatch_refresh = a.void(function(...)
  a.util.scheduler()
  M.refresh(...)
end)

local refresh_lock = a.control.Semaphore.new(1)

function M.refresh(self, callback)
  logger.debug("[REPO]: Refreshing START")

  if refresh_lock.permits == 0 then
    logger.debug("[REPO]: Refresh lock not available. Aborting refresh.")
    return
  end

  local permit = refresh_lock:acquire()
  logger.debug("[REPO]: Acquired refresh lock")

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
  permit:forget()
  logger.info("[REPO]: Refresh lock is now free")

  if callback then
    callback()
  end
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
