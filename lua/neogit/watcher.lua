-- Adapted from https://github.com/lewis6991/gitsigns.nvim/blob/main/lua/gitsigns/watcher.lua#L103

local uv = vim.loop
local logger = require("neogit.logger")

---@class Watcher
---@field gitdir string
---@field paused boolean
---@field started boolean
---@field status_buffer StatusBuffer
---@field fs_event_handler uv_fs_event_t
local Watcher = {}
Watcher.__index = Watcher

function Watcher:fs_event_callback()
  local status = require("neogit.buffers.status")

  return function(err, filename, events)
    if self.paused then
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
    status.instance:dispatch_refresh(nil, "watcher")
  end
end

function Watcher:pause()
  logger.debug("[WATCHER] Paused")
  self.paused = true
end

function Watcher:resume()
  logger.debug("[WATCHER] Resumed")
  self.paused = false
end

function Watcher:start()
  if not self.running then
    logger.debug("[WATCHER] Watching git dir: " .. self.gitdir)
    self.running = true
    self.fs_event_handler:start(self.gitdir, {}, self:fs_event_callback())
  end
end

function Watcher:stop()
  if self.running then
    logger.debug("[WATCHER] Stopped watching git dir: " .. self.gitdir)
    self.running = false
    self.fs_event_handler:stop()
  end
end

function Watcher.new(gitdir)
  if Watcher.instance then
    Watcher.instance:stop()
    Watcher.instance = nil
  end

  local instance = {
    gitdir = gitdir,
    paused = false,
    running = false,
    fs_event_handler = assert(uv.new_fs_event()),
  }

  setmetatable(instance, Watcher)

  Watcher.instance = instance
  return instance
end

function Watcher.suspend(callback, args)
  local watcher = Watcher.instance
  if watcher then
    watcher:pause()
  end

  callback(unpack(args))

  if watcher then
    watcher:resume()
  end
end

return Watcher
