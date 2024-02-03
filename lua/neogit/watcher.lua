local uv = vim.loop

local config = require("neogit.config")
local logger = require("neogit.logger")

local paused = false

local fs_event_handler = function(err, filename, events)
  if paused then
    return
  end

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
    filename == nil or
    filename:match("%.lock$") or
    filename:match("COMMIT_EDITMSG") or
    filename:match("~$") or
    filename:match("%d%d%d%d")
  then
    logger.debug(string.format("%s (ignoring)", info))
    return
  end

  logger.debug(info)
  -- TODO: Dispatch to new buffer
  require("neogit.status").dispatch_refresh(nil, "watcher")
end

-- Adapted from https://github.com/lewis6991/gitsigns.nvim/blob/main/lua/gitsigns/watcher.lua#L103
--- @param gitdir string
--- @return uv_fs_event_t
local function start(gitdir)
  local w = assert(uv.new_fs_event())
  w:start(gitdir, {}, fs_event_handler)

  return w
end

---@class Watcher
---@field gitdir string
---@field fs_event_handler uv_fs_event_t|nil
local Watcher = {}
Watcher.__index = Watcher

function Watcher:stop()
  if self.fs_event_handler then
    logger.debug("[WATCHER] Stopped watching git dir: " .. self.gitdir)
    self.fs_event_handler:stop()
  end
end

function Watcher:create(gitdir)
  self.gitdir = gitdir
  self.paused = false

  if config.values.filewatcher.enabled then
    logger.debug("[WATCHER] Watching git dir: " .. gitdir)
    self.fs_event_handler = start(gitdir)
  end

  return self
end

function Watcher.new(...)
  return Watcher:create(...)
end

function Watcher.pause()
  logger.debug("[WATCHER] Paused")
  paused = true
end

function Watcher.resume()
  logger.debug("[WATCHER] Resumed")
  paused = false
end

return Watcher
