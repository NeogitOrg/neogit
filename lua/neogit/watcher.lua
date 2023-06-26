local M = {}

local uv = vim.loop

local config = require("neogit.config")
local logger = require("neogit.logger")
local util = require("neogit.lib.util")
local status = require("neogit.status")
local git = require("neogit.lib.git")

local Path = require("plenary.path")
local a = require("plenary.async")

M.watcher = {}

local function git_dir()
  return Path.new(require("neogit.lib.git").repo.cwd .. "/.git"):absolute()
end

function M.setup()
  local gitdir = git_dir()
  local watcher = M.watch_git_dir(gitdir)

  M.watcher[gitdir] = watcher
end

-- Adapted from https://github.com/lewis6991/gitsigns.nvim/blob/main/lua/gitsigns/manager.lua#L575
--- @param gitdir string
--- @return uv_fs_event_t?
function M.watch_git_dir(gitdir)
  if not config.values.auto_refresh then
    return
  end

  if M.watcher[gitdir] then
    logger.debug(string.format("[WATCHER] for '%s' already setup! Bailing.", gitdir))
    return
  end

  local watch_gitdir_handler_db = util.debounce_trailing(
    100,
    a.void(function()
      git.repo:dispatch_refresh { callback = status.dispatch_refresh, source = "watcher" }
    end)
  )

  logger.debug("[WATCHER] Watching git dir: " .. gitdir)

  local w = assert(uv.new_fs_event())

  w:start(gitdir, {}, function(err, filename, events)
    if err then
      logger.error("[WATCHER] Git dir update error: %s", err)
      return
    end

    local info = string.format(
      "[WATCHER] Git dir update: '%s' %s",
      filename,
      vim.inspect(events, { indent = "", newline = " " })
    )

    if filename:match("%.lock$") then
      logger.debug(string.format("%s (ignoring)", info))
      return
    end

    logger.debug(info)
    watch_gitdir_handler_db()
  end)

  return w
end

return M
