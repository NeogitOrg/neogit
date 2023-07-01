local a = require("plenary.async")
local logger = require("neogit.logger")

-- git-status outputs files relative to the cwd.
--
-- Save the working directory to allow resolution to absolute paths since the
-- cwd may change after the status is refreshed and used, especially if using
-- rooter plugins with lsp integration
-- stylua: ignore start
local function empty_state()
  local root = require("neogit.lib.git.cli").git_root()
  local Path = require("plenary.path")

  return {
    git_path     = function(path)
      return Path.new(root):joinpath(".git", path)
    end,
    cwd          = vim.fn.getcwd(),
    git_root     = root,
    rev_toplevel = nil,
    head         = { branch = nil, commit_message = "" },
    upstream     = { branch = nil, commit_message = "", remote = nil },
    untracked    = { items = {} },
    unstaged     = { items = {} },
    staged       = { items = {} },
    stashes      = { items = {} },
    unpulled     = { items = {} },
    unmerged     = { items = {} },
    recent       = { items = {} },
    rebase       = { items = {}, head = nil },
    sequencer    = { items = {}, head = nil },
    merge        = { items = {}, head = nil, msg = nil },
  }
end
-- stylua: ignore end

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

local function _refresh(self, opts)
  logger.info(string.format("[REPO]: Refreshing START (source: %s)", opts.source or "UNKNOWN"))

  if self.state.git_root == "" then
    logger.debug("[REPO]: Refreshing ABORTED - No git_root")
    return
  end

  -- stylua: ignore
  if
    self.state.index.timestamp == self.state.index_stat() and
    opts.source == "watcher"
  then
    logger.debug("[REPO]: Refreshing ABORTED - .git/index hasn't been modified since last refresh")
    return
  end

  for name, fn in pairs(self.lib) do
    logger.trace(string.format("[REPO]: Refreshing %s", name))
    fn(self.state)
  end

  self.state.invalidate = {}

  logger.info("[REPO]: Refreshes completed")

  if opts.callback then
    logger.debug("[REPO]: Running refresh callback")
    opts.callback()
  end
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
  logger.debug(string.format("[REPO]: Acquiring refresh lock (source: %s)", lock_holder))
  local permit = refresh_lock:acquire()

  a.util.scheduler()
  _refresh(self, opts)

  logger.debug("[REPO]: freeing refresh lock")
  lock_holder = nil
  permit:forget()
end)

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
