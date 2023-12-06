local a = require("plenary.async")
local logger = require("neogit.logger")
local Path = require("plenary.path")
local cli = require("neogit.lib.git.cli")

local function empty_state()
  return {
    git_root = require("neogit.lib.git.cli").git_root_of_cwd(),
    head = {
      branch = nil,
      commit_message = nil,
      tag = {
        name = nil,
        distance = nil,
      },
    },
    upstream = {
      branch = nil,
      commit_message = nil,
      remote = nil,
      ref = nil,
      unmerged = { items = {} },
      unpulled = { items = {} },
    },
    pushRemote = {
      commit_message = nil,
      unmerged = { items = {} },
      unpulled = { items = {} },
    },
    untracked = { items = {} },
    unstaged = { items = {} },
    staged = { items = {} },
    stashes = { items = {} },
    recent = { items = {} },
    rebase = { items = {}, head = nil },
    sequencer = { items = {}, head = nil },
    merge = { items = {}, head = nil, msg = nil },
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
local lock_holder = nil

function M.refresh(self, opts)
  opts = opts or {}
  logger.fmt_info("[REPO]: Refreshing START (source: %s)", opts.source or "UNKNOWN")

  self.state.git_root = cli.git_root_of_cwd()

  if self.state.git_root == "" then
    logger.debug("[REPO]: Refreshing ABORTED - No git_root")
    return
  end

  if refresh_lock.permits < 1 then
    logger.fmt_debug("[REPO]: Refreshing ABORTED - Lock held by: %q", lock_holder)
    return
  end

  local permit = refresh_lock:acquire()
  lock_holder = opts.source or "UNKNOWN"
  logger.fmt_debug("[REPO]: Acquired refresh lock: %s", lock_holder)

  local cleanup = function()
    logger.info("[REPO]: Refreshes complete - freeing Refresh lock")

    lock_holder = nil
    permit:forget()

    if opts.callback then
      logger.debug("[REPO]: Running refresh callback")
      opts.callback()
    end
  end

  local update_status = function()
    logger.trace("[REPO]: Refreshing update_status")
    self.lib.update_status(self.state)
  end

  local update_all = function()
    a.util.run_all(M.updates, cleanup)
  end

  a.run(update_status, update_all)
end

function M.git_path(self, ...)
  return Path.new(self.state.git_root):joinpath(".git", ...)
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

  M.updates = {}
  for name, fn in pairs(M.lib) do
    if name ~= "update_status" then
      table.insert(M.updates, function()
        logger.trace(string.format("[REPO]: Refreshing %s", name))
        fn(M.state)
      end)
    end
  end
end

return M
