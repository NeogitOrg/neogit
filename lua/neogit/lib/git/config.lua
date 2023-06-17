local cli = require("neogit.lib.git.cli")
local logger = require("neogit.logger")

local M = {}

---@class ConfigEntry
---@field value string
---@field type string

---@type table<string, ConfigEntry>
local config_cache = {}
local cache_key = nil

local function make_cache_key()
  local stat = vim.loop.fs_stat(cli.git_root() .. "/.git/config")
  if stat then
    return stat.mtime.sec
  end
end

local function get_type_of_value(value)
  if value == "true" or value == "false" then
    return "boolean"
  elseif tonumber(value) then
    return "number"
  else
    return "string"
  end
end

local function build_config()
  local result = {}

  for _, option in ipairs(cli.config.list.call_sync():trim().stdout) do
    local key, value = option:match([[^(.-)=(.*)$]])
    result[key] = { value = value, type = get_type_of_value(value) }
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

---@return ConfigEntry|nil
function M.get(key)
  return config()[key:lower()] or {}
end

function M.get_global(key)
  return cli.config.global.get(key).call_sync_ignoring_exit_code():trim().stdout[1] or ""
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

  if not value or value == "" or value == "unset" then
    -- Unsetting a value that isn't set results in an error.
    if M.get(key).value == nil then
      return
    end

    M.unset(key)
  else
    cli.config.set(key, value).call_sync()
  end
end

function M.unset(key)
  cache_key = nil
  cli.config.unset(key).call_sync()
end

return M
