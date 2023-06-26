local a = require("plenary.async")
local logger = require("neogit.logger")
local util = require("neogit.lib.util")

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

local refresh_lock = a.control.Semaphore.new(1)
local lock_holder

M.dispatch_refresh = a.void(function(self, opts)
  opts = opts or {}

  if refresh_lock.permits == 0 then
    logger.debug(string.format("[REPO]: Refreshing ABORTED - refresh_lock held by %s", lock_holder))
    return
  end

  lock_holder = opts.source or "UNKNOWN"
  logger.info(string.format("[REPO]: Acquiring refresh lock (source: %s)", lock_holder))
  local permit = refresh_lock:acquire()

  a.util.scheduler()
  M._refresh(self, opts)

  logger.info("[REPO]: freeing refresh lock")
  lock_holder = nil
  permit:forget()
end)

function M._refresh(self, opts)
  logger.info(string.format("[REPO]: Refreshing START (source: %s)", opts.source or "UNKNOWN"))

  if self.state.git_root == "" then
    logger.info("[REPO]: Refreshing ABORTED - No git_root")
    return
  end

  self.lib.update_status(self.state)

  for name, fn in pairs(self.lib) do
    logger.info(string.format("[REPO]: Refreshing %s", name))
    fn(self.state)
  end
  logger.info("[REPO]: Refreshes completed")

  if opts.callback then
    logger.info("[REPO]: Running Callback")
    opts.callback()
  end
end

if not M.initialized then
  logger.info("[REPO]: Initializing Repository")
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
