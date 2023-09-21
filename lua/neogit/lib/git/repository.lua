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
    cwd          = vim.fn.getcwd(),
    git_root     = root,
    head         = {
      branch = nil,
      commit_message = nil,
      tag = {
        name = nil,
        distance = nil,
      },
    },
    upstream     = {
      branch         = nil,
      commit_message = nil,
      remote         = nil,
      ref            = nil,
      unmerged       = { items = {} },
      unpulled       = { items = {} },
    },
    pushRemote   = {
      commit_message = nil,
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

M._refresh_lock = a.control.Semaphore.new(1)
M._lock_holder = nil

function M.refresh(self, opts)
  opts = opts or {}
  logger.fmt_info("[REPO]: Refreshing START (source: %s)", opts.source or "UNKNOWN")

  if self.state.git_root == "" then
    logger.debug("[REPO]: Refreshing ABORTED - No git_root")
    return
  end

  if M._refresh_lock.permits < 1 then
    logger.fmt_debug("[REPO]: Refreshing ABORTED - Lock held by: %q", M._lock_holder)
    return
  end

  local permit = M._refresh_lock:acquire()
  M._lock_holder = opts.source or "UNKNOWN"
  logger.fmt_debug("[REPO]: Acquired refresh lock: %s", M._lock_holder)

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
    logger.info("[REPO]: Refreshes complete - freeing Refresh lock")

    M._lock_holder = nil
    permit:forget()

    if opts.callback then
      logger.debug("[REPO]: Running refresh callback")
      opts.callback()
    end
  end)
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
