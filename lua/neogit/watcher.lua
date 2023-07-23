local M = {}

M.watcher = {}

local uv = vim.loop

local config = require("neogit.config")
local logger = require("neogit.logger")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")

local a = require("plenary.async")

-- Adapted from https://github.com/lewis6991/gitsigns.nvim/blob/main/lua/gitsigns/manager.lua#L575
--- @param gitdir string
--- @return uv_fs_event_t?
local function start(gitdir)
  if not config.values.auto_refresh then
    return
  end

  local watch_gitdir_handler_db = util.debounce_trailing(
    200,
    a.void(function()
      logger.debug("[WATCHER] Dispatching Refresh")
      git.repo:dispatch_refresh { callback = require("neogit.status").dispatch_refresh, source = "watcher" }
    end)
  )

  logger.debug("[WATCHER] Watching git dir: " .. gitdir)

  local w = assert(uv.new_fs_event())

  w:start(
    gitdir,
    {},
    a.void(function(err, filename, events)
      if err then
        logger.error(string.format("[WATCHER] Git dir update error: %s", err))
        return
      end

      local info = string.format(
        "[WATCHER] Git dir update: '%s' %s",
        filename,
        vim.inspect(events, { indent = "", newline = " " })
      )

      -- stylua: ignore
      if
        filename:match("%.lock$") or
        filename:match("COMMIT_EDITMSG") or
        filename:match("~$")
      then
        logger.debug(string.format("%s (ignoring)", info))
        return
      end

      logger.debug(info)
      watch_gitdir_handler_db()
    end)
  )

  return w
end

function M.stop(gitdir)
  local watcher = M.watcher[gitdir]
  if watcher then
    watcher:stop()
    M.watcher[gitdir] = nil

    logger.debug("[WATCHER] Stopped watching git dir: " .. gitdir)
  end
end

function M.setup(gitdir)
  if M.watcher[gitdir] then
    logger.debug(string.format("[WATCHER] for '%s' already setup", gitdir))
    return
  end

  M.watcher[gitdir] = start(gitdir)
end

return M
