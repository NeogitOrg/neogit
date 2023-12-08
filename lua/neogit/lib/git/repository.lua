local a = require("plenary.async")
local logger = require("neogit.logger")
local Path = require("plenary.path")
local cli = require("neogit.lib.git.cli")

local function empty_state()
  return {
    git_root = cli.git_root_of_cwd(),
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

function M.refresh(self, lib)
  local refreshes = {}

  if lib then
    self.state.git_root = cli.git_root_of_cwd()
  end

  if lib and type(lib) == "table" then
    if lib.branch_information then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing branch information")
        self.lib.update_branch_information(self.state)
      end)
    end

    if lib.rebase then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing rebase information")
        self.lib.update_rebase_status(self.state)
      end)
    end

    if lib.cherry_pick then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing cherry-pick information")
        self.lib.update_cherry_pick_status(self.state)
      end)
    end

    if lib.merge then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing merge information")
        self.lib.update_merge_status(self.state)
      end)
    end

    if lib.stashes then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing stash")
        self.lib.update_stashes(self.state)
      end)
    end

    if lib.unpulled then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing unpulled commits")
        self.lib.update_unpulled(self.state)
      end)
    end

    if lib.unmerged then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing unpushed commits")
        self.lib.update_unmerged(self.state)
      end)
    end

    if lib.recent then
      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing recent commits")
        self.lib.update_recent(self.state)
      end)
    end

    if lib.diffs then
      local filter = (type(lib) == "table" and type(lib.diffs) == "table") and lib.diffs or nil

      table.insert(refreshes, function()
        logger.debug("[REPO]: Refreshing diffs")
        self.lib.update_diffs(self.state, filter)
      end)
    end
  else
    logger.debug("[REPO]: Refreshing ALL")
    for name, fn in pairs(self.lib) do
      if name ~= "update_status" then
        table.insert(refreshes, function()
          logger.debug("[REPO]: Refreshing " .. name)
          fn(self.state)
        end)
      end
    end
  end

  logger.debug(string.format("[REPO]: Running %d refresh(es)", #refreshes))
  logger.debug("[REPO]: Refreshing status")
  self.lib.update_status(self.state)
  a.util.join(refreshes)
  logger.debug("[REPO]: Refreshes completed")
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
end

return M
