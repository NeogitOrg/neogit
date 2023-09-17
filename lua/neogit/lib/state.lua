local logger = require("neogit.logger")
local config = require("neogit.config")
local Path = require("plenary.path")

local M = {}

M.loaded = false

local function log(message)
  logger.debug(string.format("[STATE]: %s: '%s'", message, M.path:absolute()))
end

---@return Path
function M.filepath()
  local base_path = vim.fn.stdpath("state") .. "/neogit/"
  local filename = "state"

  if config.values.use_per_project_settings then
    filename = vim.loop.cwd():gsub("/", "%%")
  end

  if vim.loop.os_uname().sysname == "Windows_NT" then
    base_path = base_path:gsub("/", "\\")
    filename = filename:gsub("\\", "%%")
  end

  return Path:new(base_path .. filename)
end

---Initializes state
function M.setup()
  if M.loaded then
    return
  end

  M.path = M.filepath()
  M.loaded = true
  M.state = M.read()
  log("Loaded")
end

---@return boolean
function M.enabled()
  return M.loaded and config.values.remember_settings
end

---Reads state from disk
---@return table
function M.read()
  if not M.enabled() then
    return {}
  end

  if not M.path:exists() then
    log("Creating file")
    M.path:touch { parents = true }
    M.path:write(vim.mpack.encode {}, "w")
  end

  log("Reading file")
  return vim.mpack.decode(M.path:read())
end

---Writes state to disk
function M.write()
  if not M.enabled() then
    return
  end

  log("Writing file")
  M.path:write(vim.mpack.encode(M.state), "w")
end

---Construct a cache-key from a table
---@param key_table table
---@return string
local function gen_key(key_table)
  return table.concat(key_table, "--")
end

---Set option and write to disk
---@param key table
---@param value any
function M.set(key, value)
  if not M.enabled() then
    return
  end

  if not vim.tbl_contains(config.values.ignored_settings, gen_key(key)) then
    M.state[gen_key(key)] = value
    M.write()
  end
end

---Get option. If value isn't set, return provided default.
---@param key table
---@param default any
---@return any
function M.get(key, default)
  if not M.enabled() then
    return default
  end

  local value = M.state[gen_key(key)]
  if value ~= nil then
    return value
  else
    return default
  end
end

---Reset current state, removing whats written to disk
function M._reset()
  log("Reset file")
  M.path:write(vim.mpack.encode {}, "w")
  M.state = {}
end

return M
