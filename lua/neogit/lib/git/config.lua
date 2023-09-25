local cli = require("neogit.lib.git.cli")
local logger = require("neogit.logger")

local M = {}

---@class ConfigEntry
---@field value string
---@field name string
---@field scope string Global/System/Local
local ConfigEntry = {}
ConfigEntry.__index = ConfigEntry

---@param name string
---@return ConfigEntry
function ConfigEntry.new(name, value, scope)
  return setmetatable({
    name = name,
    value = value or "",
    scope = scope,
  }, ConfigEntry)
end

---@return string
function ConfigEntry:type()
  if self.value == "true" or self.value == "false" then
    return "boolean"
  elseif tonumber(self.value) then
    return "number"
  else
    return "string"
  end
end

---@return boolean
function ConfigEntry:is_set()
  return self.value ~= ""
end

---@return boolean
function ConfigEntry:is_unset()
  return not self:is_set()
end

---@return boolean|number|string|nil
function ConfigEntry:read()
  if self:is_unset() then
    return nil
  end

  if self:type() == "boolean" then
    return self.value == "true"
  elseif self:type() == "number" then
    return tonumber(self.value)
  else
    return self.value
  end
end

---@return nil
function ConfigEntry:update(value)
  if not value or value == "" then
    if self:is_set() then
      M.unset(self.name)
    end
  else
    M.set(self.name, value)
  end
end

---@type table<string, ConfigEntry>
local config_cache = {}
local cache_key = nil
local git_root = cli.git_root()

local function make_cache_key()
  local stat = vim.loop.fs_stat(git_root .. "/.git/config")
  if stat then
    return stat.mtime.sec
  end
end

local function build_config()
  local result = {}

  for _, option in ipairs(cli.config.list._local.call_sync():trim().stdout) do
    local key, value = option:match([[^(.-)=(.*)$]])
    result[key] = ConfigEntry.new(key, value, "local")
  end

  return result
end

local function config()
  if not cache_key or cache_key ~= make_cache_key() then
    logger.debug("[Config] Rebuilding git config_cache")
    cache_key = make_cache_key()
    config_cache = build_config()
  end

  return config_cache
end

---@return ConfigEntry
function M.get(key)
  return config()[key:lower()] or ConfigEntry.new(key, "", "local")
end

---@return ConfigEntry
function M.get_global(key)
  local result = cli.config.global.get(key).call_sync_ignoring_exit_code():trim().stdout[1]
  return ConfigEntry.new(key, result, "global")
end

function M.get_matching(pattern)
  local matches = {}
  for key, value in pairs(config()) do
    if key:match(pattern) then
      matches[key] = value
    end
  end

  return matches
end

function M.set(key, value)
  cache_key = nil

  if not value or value == "" then
    M.unset(key)
  else
    cli.config.set(key, value).call_sync()
  end
end

function M.unset(key)
  -- Unsetting a value that isn't set results in an error.
  if not M.get(key):is_set() then
    return
  end

  cache_key = nil
  cli.config.unset(key).call_sync()
end

return M
