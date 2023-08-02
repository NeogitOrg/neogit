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
    git_path     = function(...)
      return Path.new(root):joinpath(".git", ...)
    end,
    cwd          = vim.loop.cwd(),
    git_root     = root,
    head         = { branch = nil, commit_message = "" },
    upstream     = {
      branch         = nil,
      commit_message = "",
      remote         = nil,
      ref            = nil,
      unmerged       = { items = {} },
      unpulled       = { items = {} },
    },
    pushRemote   = {
      commit_message = "",
      unmerged       = { items = {} },
      unpulled       = { items = {} },
    },
    untracked    = { items = {} },
    unstaged     = { items = {} },
    staged       = { items = {} },
    stashes      = { items = {} },
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

local refresh_lock = a.control.Semaphore.new(1)
local lock_holder

local function refresh(self, opts)
  opts = opts or {}

  logger.info(string.format("[REPO]: Refreshing START (source: %s)", opts.source or "UNKNOWN"))

  if refresh_lock.permits == 0 then
    logger.debug(string.format("[REPO]: Refreshing ABORTED - refresh_lock held by %s", lock_holder))
    return
  end

  if self.state.git_root == "" then
    logger.debug("[REPO]: Refreshing ABORTED - No git_root")
    return
  end

  lock_holder = opts.source or "UNKNOWN"
  logger.debug(string.format("[REPO]: Acquiring refresh lock (source: %s)", lock_holder))
  local permit = refresh_lock:acquire()

  a.util.scheduler()
  -- Status needs to run first because other update fn's depend on it
  logger.trace("[REPO]: Refreshing update_status")
  self.lib.update_status(self.state)

  local updates = {}
  for name, fn in pairs(self.lib) do
    if name ~= "update_status" then
      table.insert(updates, function()
        logger.trace(string.format("[REPO]: Refreshing %s", name))
        fn(self.state)
      end)
    end
  end

  a.util.run_all(updates, function()
    logger.info("[REPO]: Refreshes completed - freeing refresh lock")
    permit:forget()
    lock_holder = nil

    if opts.callback then
      logger.debug("[REPO]: Running refresh callback")
      opts.callback()
    end
  end)
end

M.dispatch_refresh = a.void(refresh)

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
