local a = require("plenary.async")
local logger = require("neogit.logger")
local Path = require("plenary.path") ---@class Path
local git = require("neogit.lib.git")
local ItemFilter = require("neogit.lib.item_filter")

local modules = {
  "status",
  "branch",
  "stash",
  "pull",
  "push",
  "log",
  "rebase",
  "sequencer",
  "merge",
  "bisect",
  "tag",
  "refs",
}

---@class NeogitRepoState
---@field git_path       fun(self, ...):Path
---@field refresh        fun(self, table)
---@field initialized    boolean
---@field git_root       string
---@field refresh_lock   Semaphore
---@field head           NeogitRepoHead
---@field upstream       NeogitRepoRemote
---@field pushRemote     NeogitRepoRemote
---@field untracked      NeogitRepoIndex
---@field unstaged       NeogitRepoIndex
---@field staged         NeogitRepoIndex
---@field stashes        NeogitRepoStash
---@field recent         NeogitRepoRecent
---@field sequencer      NeogitRepoSequencer
---@field rebase         NeogitRepoRebase
---@field merge          NeogitRepoMerge
---@field bisect         NeogitRepoBisect
---
---@class NeogitRepoHead
---@field branch         string|nil
---@field oid            string|nil
---@field abbrev         string|nil
---@field detached       boolean
---@field commit_message string|nil
---@field tag            NeogitRepoHeadTag
---
---@class NeogitRepoHeadTag
---@field name           string|nil
---@field oid            string|nil
---@field distance       number|nil
---
---@class NeogitRepoRemote
---@field branch         string|nil
---@field commit_message string|nil
---@field remote         string|nil
---@field ref            string|nil
---@field abbrev         string|nil
---@field oid            string|nil
---@field unmerged       NeogitRepoIndex
---@field unpulled       NeogitRepoIndex
---
---@class NeogitRepoIndex
---@field items          StatusItem[]
---
---@class NeogitRepoStash
---@field items          StashItem[]
---
---@class NeogitRepoRecent
---@field items          CommitItem[]
---
---@class NeogitRepoSequencer
---@field items          SequencerItem[]
---@field head           string|nil
---@field head_oid       string|nil
---@field revert         boolean
---@field cherry_pick    boolean
---
---@class NeogitRepoRebase
---@field items          RebaseItem[]
---@field onto           RebaseOnto
---@field head           string|nil
---@field current        string|nil
---
---@class NeogitRepoMerge
---@field items          MergeItem[]
---@field head           string|nil
---@field msg            string
---@field branch         string|nil
---
---@class NeogitRepoBisect
---@field items          BisectItem[]
---@field finished       boolean
---@field current        CommitLogEntry

---@return NeogitRepoState
local function empty_state()
  return {
    initialized = false,
    git_root = "",
    head = {
      branch = nil,
      detached = false,
      commit_message = nil,
      abbrev = nil,
      oid = nil,
      tag = {
        name = nil,
        oid = nil,
        distance = nil,
      },
    },
    upstream = {
      branch = nil,
      commit_message = nil,
      abbrev = nil,
      remote = nil,
      ref = nil,
      oid = nil,
      unmerged = { items = {} },
      unpulled = { items = {} },
    },
    pushRemote = {
      branch = nil,
      commit_message = nil,
      abbrev = nil,
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
    rebase = {
      items = {},
      onto = {},
      head = nil,
      current = nil,
    },
    sequencer = {
      items = {},
      head = nil,
      head_oid = nil,
      revert = false,
      cherry_pick = false,
    },
    merge = {
      items = {},
      head = nil,
      msg = "",
      branch = nil,
    },
    bisect = {
      items = {},
      finished = false,
      current = {},
    },
    refs = {},
  }
end

---@class NeogitRepo
---@field lib table
---@field state NeogitRepoState
---@field git_root string
local Repo = {}
Repo.__index = Repo

local instances = {}

---@param dir? string
function Repo.instance(dir)
  dir = dir or vim.uv.cwd()
  assert(dir, "cannot create a repo without a cwd")

  local cwd = vim.fs.normalize(dir)
  if not instances[cwd] then
    logger.debug("[REPO]: Registered Repository for: " .. cwd)
    instances[cwd] = Repo.new(cwd)
  end

  return instances[cwd]
end

-- Use Repo.instance when calling directly to ensure it's registered
---@param dir string
function Repo.new(dir)
  logger.debug("[REPO]: Initializing Repository")

  local instance = {
    lib = {},
    state = empty_state(),
    git_root = git.cli.git_root(dir),
    refresh_lock = a.control.Semaphore.new(1),
  }

  instance.state.git_root = instance.git_root

  setmetatable(instance, Repo)

  for _, m in ipairs(modules) do
    require("neogit.lib.git." .. m).register(instance.lib)
  end

  return instance
end

function Repo:reset()
  self.state = empty_state()
end

function Repo:git_path(...)
  return Path:new(self.git_root):joinpath(".git", ...)
end

function Repo:tasks(filter)
  local tasks = {}
  for name, fn in pairs(self.lib) do
    table.insert(tasks, function()
      local start = vim.uv.now()
      fn(self.state, filter)
      logger.debug(("[REPO]: Refreshed %s in %d ms"):format(name, vim.uv.now() - start))
    end)
  end

  return tasks
end

function Repo:acquire_lock()
  local permit = self.refresh_lock:acquire()

  vim.defer_fn(function()
    if self.refresh_lock.permits == 0 then
      logger.debug("[REPO]: Refresh lock expired after 10 seconds")
      permit:forget()
    end
  end, 10000)

  return permit
end

function Repo:refresh(opts)
  if self.git_root == "" then
    logger.debug("[REPO] No git root found - skipping refresh")
    return
  end

  if not self.state.initialized then
    self.state.initialized = true
  end

  local start = vim.uv.now()
  opts = opts or {}

  local permit = self:acquire_lock()
  logger.info(("[REPO]: Acquired Refresh Lock for %s"):format(opts.source or "UNKNOWN"))

  local on_complete = function()
    logger.debug("[REPO]: Refreshes complete in " .. vim.uv.now() - start .. " ms")

    if opts.callback then
      logger.debug("[REPO]: Running refresh callback")
      opts.callback()
    end

    logger.info(("[REPO]: Releasing Lock for %s"):format(opts.source or "UNKNOWN"))
    permit:forget()
  end

  local filter = ItemFilter.create { "*:*" }
  if opts.partial and opts.partial.update_diffs then
    filter = ItemFilter.create(opts.partial.update_diffs)
  end

  a.util.run_all(self:tasks(filter), on_complete)
end

return Repo
