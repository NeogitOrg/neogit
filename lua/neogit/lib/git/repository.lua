local a = require("plenary.async")
local logger = require("neogit.logger")
local Path = require("plenary.path") ---@class Path
local Watcher = require("neogit.watcher")
local git = require("neogit.lib.git")
local ItemFilter = require("neogit.lib.item_filter")
local util = require("neogit.lib.util")

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
---@field head_oid       string|nil
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
---@field running boolean
---@field refresh_callbacks function[]
local Repo = {}
Repo.__index = Repo

local instances = {}

---@param dir? string
---@return NeogitRepo
function Repo.instance(dir)
  dir = dir or vim.uv.cwd()
  assert(dir, "cannot create a repo without a cwd")

  local cwd = vim.fs.normalize(dir)
  if not instances[cwd] then
    logger.debug("[REPO]: Registered Repository for: " .. cwd)
    instances[cwd] = Repo.new(cwd)
    instances[cwd]:dispatch_refresh()
  end

  return instances[cwd]
end

-- Use Repo.instance when calling directly to ensure it's registered
---@param dir string
---@return NeogitRepo
function Repo.new(dir)
  logger.debug("[REPO]: Initializing Repository")

  local instance = {
    lib = {},
    state = empty_state(),
    git_root = git.cli.git_root(dir),
    running = false,
    refresh_callbacks = {},
    semaphore = a.control.Semaphore.new(1),
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
  return function(state)
    local tasks = {}
    for name, fn in pairs(self.lib) do
      table.insert(tasks, function()
        local start = vim.uv.now()

        fn(state, filter)
        logger.debug(("[REPO]: Refreshed %s in %d ms"):format(name, vim.uv.now() - start))
      end)
    end

    return tasks
  end
end

function Repo:refresh(opts, permit, start)
  opts = opts or {}

  if self.git_root == "" then
    logger.debug("[REPO] No git root found - skipping refresh")
    return
  end

  local filter = ItemFilter.create { "*:*" }
  -- if opts.partial and opts.partial.update_diffs then
  --   filter = ItemFilter.create(opts.partial.update_diffs)
  -- end

  local new_state = empty_state()
  new_state.initialized = true
  new_state.git_root = self.state.git_root

  local on_complete = function()
    self.state = new_state
    vim.uv.update_time()
    logger.debug("[REPO]: Refreshes complete in " .. vim.uv.now() - start .. " ms")
    if opts.callback then
      opts.callback()
    end

    if
      git.rebase.in_progress()
      or git.merge.in_progress()
      or git.bisect.in_progress()
      or git.sequencer.pick_or_revert_in_progress()
    then
      Watcher.instance(self.git_root):start()
    else
      Watcher.instance(self.git_root):stop()
    end

    permit:forget()
    logger.debug("[REPO] Released lock " .. start)
  end

  a.util.run_all(self:tasks(filter)(new_state), on_complete)
end

Repo.dispatch_refresh = a.void(function(self, opts)
  vim.uv.update_time()
  local start = vim.uv.now()
  local permit = self.semaphore:acquire()

  vim.uv.update_time()
  local start2 = vim.uv.now()
  self.lock = start2
  logger.debug("[REPO] Acquired lock " .. self.lock .. " after " .. start2 - start)

  vim.defer_fn(function()
    if self.lock == start and self.semaphore.permits < 1 then
      logger.debug("[REPO] Timeout - released lock " .. self.lock)
      permit:forget()
    end
  end, 1000)

  self:refresh(opts, permit, start2)
end)

return Repo
