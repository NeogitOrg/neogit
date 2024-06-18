-- Adapted from https://github.com/lewis6991/gitsigns.nvim/blob/main/lua/gitsigns/watcher.lua#L103

local logger = require("neogit.logger")
local Path = require("plenary.path")
local util = require("neogit.lib.util")
local config = require("neogit.config")

---@class Watcher
---@field git_root string
---@field buffers table<StatusBuffer|RefsViewBuffer>
---@field running boolean
---@field fs_event_handler uv_fs_event_t
local Watcher = {}
Watcher.__index = Watcher

---@param root string
---@return Watcher
function Watcher.new(root)
  local instance = {
    buffers = {},
    git_root = Path:new(root):joinpath(".git"):absolute(),
    running = false,
    fs_event_handler = assert(vim.loop.new_fs_event()),
  }

  setmetatable(instance, Watcher)

  return instance
end

local instances = {}

---@param root string
---@return Watcher
function Watcher.instance(root)
  if not instances[root] then
    instances[root] = Watcher.new(root)
  end

  return instances[root]
end

---@param buffer StatusBuffer|RefsViewBuffer
---@return Watcher
function Watcher:register(buffer)
  self.buffers[buffer:id()] = buffer
  return self:start()
end

---@return Watcher
function Watcher:unregister(buffer)
  self.buffers[buffer:id()] = nil
  if vim.tbl_isempty(self.buffers) then
    self:stop()
  end

  return self
end

---@return Watcher
function Watcher:start()
  if config.values.filewatcher.enabled and not self.running then
    self.running = true

    logger.debug("[WATCHER] Watching git dir: " .. self.git_root)
    self.fs_event_handler:start(self.git_root, {}, self:fs_event_callback())
  end
end

---@return Watcher
function Watcher:stop()
  if self.running then
    self.running = false

    logger.debug("[WATCHER] Stopped watching git dir: " .. self.git_root)
    self.fs_event_handler:stop()
  end

  return self
end

local WATCH_IGNORE = {
  ORIG_HEAD = true,
  FETCH_HEAD = true,
  COMMIT_EDITMSG = true,
}

function Watcher:fs_event_callback()
  local refresh_debounced = util.debounce_trailing(200, function(info)
    logger.debug(info)

    for name, buffer in pairs(self.buffers) do
      logger.debug("[WATCHER] Dispatching refresh to " .. name)
      buffer:dispatch_refresh(nil, "watcher")
    end
  end)

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
      WATCH_IGNORE[filename] or
      vim.endswith(filename, ".lock") or
      vim.endswith(filename, "~") or
      filename:match("%d%d%d%d")
    then
      return
    end

    refresh_debounced(info)
  end
end

return Watcher
