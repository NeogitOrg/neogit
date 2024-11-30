local a = require("plenary.async")
local logger = require("neogit.logger")
local Path = require("plenary.path")
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
  "hooks",
}

---@class NeogitRepoState
---@field git_path          fun(self, ...): Path
---@field worktree_git_path fun(self, ...): Path
---@field refresh           fun(self, table)
---@field worktree_root     string Absolute path to the root of the current worktree
---@field worktree_git_dir  string Absolute path to the .git/ dir of the current worktree
---@field git_dir           string Absolute path of the .git/ dir for the repository
---@field head              NeogitRepoHead
---@field upstream          NeogitRepoRemote
---@field pushRemote        NeogitRepoRemote
---@field untracked         NeogitRepoIndex
---@field unstaged          NeogitRepoIndex
---@field staged            NeogitRepoIndex
---@field stashes           NeogitRepoStash
---@field recent            NeogitRepoRecent
---@field sequencer         NeogitRepoSequencer
---@field rebase            NeogitRepoRebase
---@field merge             NeogitRepoMerge
---@field bisect            NeogitRepoBisect
---@field hooks             string[]
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
    worktree_root = "",
    worktree_git_dir = "",
    git_dir = "",
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
---@field lib               table
---@field state             NeogitRepoState
---@field worktree_root     string Project root, or  worktree
---@field worktree_git_dir  string Dir to watch for changes in worktree
---@field git_dir           string '.git/' directory for repo
---@field running           table
---@field interrupt         table
---@field tmp_state         table
---@field refresh_callbacks function[]
local Repo = {}
Repo.__index = Repo

local instances = {}
local lastDir = vim.uv.cwd()

---@param dir? string
---@return NeogitRepo
function Repo.instance(dir)
  if dir and dir ~= lastDir then
    lastDir = dir
  end

  assert(lastDir, "No last dir")
  local cwd = vim.fs.normalize(lastDir)
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
    worktree_root = git.cli.worktree_root(dir),
    worktree_git_dir = git.cli.worktree_git_dir(dir),
    git_dir = git.cli.git_dir(dir),
    refresh_callbacks = {},
    running = util.weak_table(),
    interrupt = util.weak_table(),
    tmp_state = util.weak_table("v"),
  }

  instance.state.worktree_root = instance.worktree_root
  instance.state.worktree_git_dir = instance.worktree_git_dir
  instance.state.git_dir = instance.git_dir

  setmetatable(instance, Repo)

  for _, m in ipairs(modules) do
    require("neogit.lib.git." .. m).register(instance.lib)
  end

  return instance
end

function Repo:reset()
  self.state = empty_state()
end

---@return Path
function Repo:worktree_git_path(...)
  return Path:new(self.worktree_git_dir):joinpath(...)
end

---@return Path
function Repo:git_path(...)
  return Path:new(self.git_dir):joinpath(...)
end

function Repo:tasks(filter, state)
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

function Repo:register_callback(source, fn)
  logger.debug("[REPO] Callback registered from " .. source)
  self.refresh_callbacks[source] = fn
end

function Repo:run_callbacks(id)
  for source, fn in pairs(self.refresh_callbacks) do
    logger.debug("[REPO]: (" .. id .. ") Running callback for " .. source)
    fn()
  end

  self.refresh_callbacks = {}
end

local DEFAULT_FILTER = ItemFilter.create { "*:*" }

local function timestamp()
  vim.uv.update_time()
  return vim.uv.now()
end

function Repo:current_state(id)
  if not self.tmp_state[id] then
    self.tmp_state[id] = vim.deepcopy(self.state)
  end
  return self.tmp_state[id]
end

function Repo:set_state(id)
  self.state = self:current_state(id)
end

function Repo:refresh(opts)
  if self.worktree_root == "" then
    logger.debug("[REPO] No git root found - skipping refresh")
    return
  end

  opts = opts or {}

  local start = timestamp()

  if opts.callback then
    self:register_callback(opts.source, opts.callback)
  end

  if vim.tbl_keys(self.running)[1] then
    for k, v in pairs(self.running) do
      if v then
        logger.debug("[REPO] (" .. start .. ") Already running - setting interrupt for " .. k)
        self.interrupt[k] = true
      end
    end
  end

  self.running[start] = true

  local filter
  if opts.partial and opts.partial.update_diffs then
    filter = ItemFilter.create(opts.partial.update_diffs)
  else
    filter = DEFAULT_FILTER
  end

  local on_complete = a.void(function()
    self.running[start] = false
    if self.interrupt[start] then
      logger.debug("[REPO]: (" .. start .. ") Interrupting on_complete callback")
      return
    end

    logger.debug("[REPO]: (" .. start .. ") Refreshes complete in " .. timestamp() - start .. " ms")
    self:set_state(start)
    self:run_callbacks(start)
  end)

  a.util.run_all(self:tasks(filter, self:current_state(start)), on_complete)
end

Repo.dispatch_refresh = a.void(function(self, opts)
  self:refresh(opts)
end)

return Repo
