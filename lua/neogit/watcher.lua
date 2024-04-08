-- Adapted from https://github.com/lewis6991/gitsigns.nvim/blob/main/lua/gitsigns/watcher.lua#L103

local logger = require("neogit.logger")
local Path = require("plenary.path")

---@class Watcher
---@field git_root string
---@field status_buffer StatusBuffer
---@field running boolean
---@field fs_event_handler uv_fs_event_t
local Watcher = {}
Watcher.__index = Watcher

function Watcher.new(status_buffer, root)
  local instance = {
    status_buffer = status_buffer,
    git_root = Path.new(root):joinpath(".git"):absolute(),
    running = false,
    fs_event_handler = assert(vim.loop.new_fs_event()),
  }

  setmetatable(instance, Watcher)

  return instance
end

function Watcher:start()
  if not self.running then
    self.running = true

    logger.debug("[WATCHER] Watching git dir: " .. self.git_root)
    self.fs_event_handler:start(self.git_root, {}, self:fs_event_callback())
  end
end

function Watcher:stop()
  if self.running then
    self.running = false

    logger.debug("[WATCHER] Stopped watching git dir: " .. self.git_root)
    self.fs_event_handler:stop()
  end
end

function Watcher:fs_event_callback()
  return function(err, filename, events)
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
    self.status_buffer:dispatch_refresh(nil, "watcher")
  end
end

return Watcher
