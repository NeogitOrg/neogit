local a = require("plenary.async")
local logger = require("neogit.logger")
local Path = require("plenary.path")
local cli = require("neogit.lib.git.cli")

local function empty_state()
  ---@class NeogitRepo
  return {
    git_root = cli.git_root_of_cwd(),
    head = {
      branch = nil,
      oid = nil,
      commit_message = nil,
      tag = {
        name = nil,
        oid = nil,
        distance = nil,
      },
    },
    upstream = {
      branch = nil,
      commit_message = nil,
      remote = nil,
      ref = nil,
      oid = nil,
      unmerged = { items = {} },
      unpulled = { items = {} },
    },
    pushRemote = {
      branch = nil,
      commit_message = nil,
      remote = nil,
      ref = nil,
      oid = nil,
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

local meta = {
  __index = function(self, method)
    return self.state[method]
  end,
}

local M = {}

M.state = empty_state()
M.lib = {}
M.updates = {}

function M.reset(self)
  self.state = empty_state()
end

function M.refresh(self, opts)
  opts = opts or {}
  logger.fmt_info("[REPO]: Refreshing START (source: %s)", opts.source or "UNKNOWN")

  local cleanup = function()
    logger.debug("[REPO]: Refreshes complete")

    if opts.callback then
      logger.debug("[REPO]: Running refresh callback")
      opts.callback()
    end
  end

  -- Needed until Process doesn't use vim.fn.*
  a.util.scheduler()

  self.state.git_root = cli.git_root_of_cwd()

  -- This needs to be run before all others, because libs like Pull and Push depend on it setting some state.
  logger.debug("[REPO]: Refreshing 'update_status'")
  self.lib.update_status(self.state)

  local tasks = {}
  if opts.partial then
    for name, fn in pairs(M.lib) do
      if opts.partial[name] then
        local filter = type(opts.partial[name]) == "table" and opts.partial[name]

        table.insert(tasks, function()
          logger.fmt_debug("[REPO]: Refreshing %s", name)
          fn(M.state, filter)
        end)
      end
    end
  else
    tasks = M.updates
  end

  a.util.run_all(tasks, cleanup)
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
    "branch",
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

  for name, fn in pairs(M.lib) do
    if name ~= "update_status" then
      table.insert(M.updates, function()
        logger.fmt_debug("[REPO]: Refreshing %s", name)
        fn(M.state)
      end)
    end
  end
end

return M
