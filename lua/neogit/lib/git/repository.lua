local a = require("plenary.async")
local logger = require("neogit.logger")

-- git-status outputs files relative to the cwd.
--
-- Save the working directory to allow resolution to absolute paths since the
-- cwd may change after the status is refreshed and used, especially if using
-- rooter plugins with lsp integration
-- stylua: ignore start
local function empty_state(cwd)
  local root = require("neogit.lib.git.cli").git_root()
  local Path = require("plenary.path")

  return {
    git_path     = function(path)
      return Path.new(root):joinpath(".git", path)
    end,
    index_stat   = function()
      local index = Path.new(root):joinpath(".git", "index")
      if index:exists() then
        return index:_stat().mtime.sec
      end
    end,
    cwd          = cwd,
    git_root     = root,
    rev_toplevel = nil,
    invalid      = {},
    index        = { timestamp = 0 },
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

local Repo = {}
Repo.__index = Repo

function Repo.new(cwd)
  logger.info(string.format("[REPO]: Initializing Repository for %s", cwd))

  local repo = setmetatable(
    vim.tbl_extend("error", empty_state(cwd), {
      lib = {},
      refresh_lock = a.control.Semaphore.new(1),
      lock_holder = nil,
    }),
    Repo
  )

  local modules = {
    "status",
    "index",
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
    require("neogit.lib.git." .. m).register(repo.lib)
  end

  return repo
end

function Repo:reset()
  vim.tbl_extend("force", self, empty_state(vim.fn.getcwd()))
end

-- Invalidates a cached diff for a file
function Repo:invalidate(...)
  local files = { ... }
  for _, path in ipairs(files) do
    table.insert(self.invalid, string.format("*:%s", path))
  end
end

function Repo:dispatch_refresh(opts)
  a.void(function(self, opts)
    opts = opts or {}

    logger.info(string.format("[REPO]: Refreshing START (source: %s)", opts.source or "UNKNOWN"))

    if self.refresh_lock.permits == 0 then
      logger.debug(string.format("[REPO]: Refreshing ABORTED - refresh_lock held by %s", self.lock_holder))
      return
    end

    -- stylua: ignore
    if
      self.index.timestamp == self.index_stat() and
      opts.source == "watcher"
    then
      logger.debug("[REPO]: Refreshing ABORTED - .git/index hasn't been modified since last refresh")
      return
    end

    if self.git_root == "" then
      logger.debug("[REPO]: Refreshing ABORTED - No git_root")
      return
    end

    self.lock_holder = opts.source or "UNKNOWN"
    logger.debug(string.format("[REPO]: Acquiring refresh lock (source: %s)", self.lock_holder))
    local permit = self.refresh_lock:acquire()

    a.util.scheduler()

    -- Status needs to run first because other update fn's depend on it
    logger.trace("[REPO]: Refreshing %s", "update_status")
    self.lib.update_status(self)

    local updates = {}
    for name, fn in pairs(self.lib) do
      if name ~= "update_status" then
        table.insert(updates, function()
          logger.trace(string.format("[REPO]: Refreshing %s", name))
          fn(self)
        end)
      end
    end

    a.util.run_all(updates, function()
      self.invalid = {}

      logger.info("[REPO]: Refreshes completed - freeing refresh lock")
      permit:forget()
      self.lock_holder = nil

      if opts.callback then
        logger.debug("[REPO]: Running refresh callback")
        opts.callback()
      end
    end)
  end)(self, opts)
end

return Repo
