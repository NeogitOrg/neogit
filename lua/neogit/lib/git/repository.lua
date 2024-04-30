local a = require("plenary.async")
local logger = require("neogit.logger")
local Path = require("plenary.path") ---@class Path
local git = require("neogit.lib.git")

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
  "bisect",
}

---@class NeogitRepo
---@field git_path       fun(self, ...):Path
---@field refresh        fun(self, table)
---@field initialized    boolean
---@field git_root       string
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

---@return NeogitRepo
local function empty_state()
  return {
    initialized = false,
    git_root = "",
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
  }
end

---@class NeogitRepo
local Repo = {}
Repo.__index = Repo

local instances = {}

function Repo.instance(dir)
  local cwd = dir or vim.loop.cwd()
  if cwd and not instances[cwd] then
    instances[cwd] = Repo.new(cwd)
  end

  return instances[cwd]
end

-- Use Repo.instance when calling directly to ensure it's registered
function Repo.new(dir)
  logger.debug("[REPO]: Initializing Repository")

  local instance = {
    lib = {},
    updates = {},
    state = empty_state(),
    git_root = git.cli.git_root(dir),
  }

  instance.state.git_root = instance.git_root

  setmetatable(instance, Repo)

  for _, m in ipairs(modules) do
    require("neogit.lib.git." .. m).register(instance.lib)
  end

  for name, fn in pairs(instance.lib) do
    if name ~= "update_status" then
      table.insert(instance.updates, function()
        logger.debug(("[REPO]: Refreshing %s"):format(name))
        fn(instance.state)
      end)
    end
  end

  return instance
end

function Repo:reset()
  self.state = empty_state()
end

function Repo:git_path(...)
  return Path.new(self.git_root):joinpath(".git", ...)
end

function Repo:refresh(opts)
  if self.git_root == "" then
    logger.debug("[REPO] No git root found - skipping refresh")
    return
  end

  self.state.initialized = true
  opts = opts or {}
  logger.info(("[REPO]: Refreshing START (source: %s)"):format(opts.source or "UNKNOWN"))

  -- Needed until Process doesn't use vim.fn.*
  a.util.scheduler()

  -- This needs to be run before all others, because libs like Pull and Push depend on it setting some state.
  logger.debug("[REPO]: Refreshing 'update_status'")
  self.lib.update_status(self.state)

  local tasks = {}
  if opts.partial then
    for name, fn in pairs(self.lib) do
      if opts.partial[name] then
        local filter = type(opts.partial[name]) == "table" and opts.partial[name]

        table.insert(tasks, function()
          logger.debug(("[REPO]: Refreshing %s"):format(name))
          fn(self.state, filter)
        end)
      end
    end
  else
    tasks = self.updates
  end

  a.util.run_all(tasks, function()
    logger.debug("[REPO]: Refreshes complete")

    if opts.callback then
      logger.debug("[REPO]: Running refresh callback")
      opts.callback()
    end
  end)
end

return Repo
