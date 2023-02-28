local logger = require("neogit.logger")
local config = require("neogit.config")
local Path = require("plenary.path")

local M = {}

function M.filepath()
  local base_path = vim.fn.stdpath("state") .. "/neogit/"
  if config.values.use_per_project_settings then
    return Path:new(base_path .. vim.loop.cwd():gsub("/", "%%"))
  else
    return Path:new(base_path .. "state")
  end
end

function M.enabled()
  return config.values.remember_settings
end

function M.read()
  if not M.enabled() then return {} end

  if not M.filepath():exists() then
    logger.debug("State: Creating file: '" .. M.filepath():absolute() .. "'")
    M.filepath():touch({ parents = true })
    M.filepath():write(vim.mpack.encode({}), "w")
  end

  logger.debug("State: Reading file: '" .. M.filepath():absolute() .. "'")
  return vim.mpack.decode(M.filepath():read())
end

function M.write()
  if not M.enabled() then return end

  logger.debug("State: Writing file: '" .. M.filepath():absolute() .. "'")
  M.filepath():write(vim.mpack.encode(M.state), "w")
end

local function gen_key(key_table)
  return table.concat(key_table, "--")
end

function M.set(key, value)
  if not M.enabled() then return end

  M.state[gen_key(key)] = value
  M.write()
end

function M.get(key, default)
  if not M.enabled() then return default end

  return M.state[gen_key(key)] or default
end

function M._reset()
  logger.debug("State: Reset file: '" .. M.filepath():absolute() .. "'")
  M.filepath():write(vim.mpack.encode({}), "w")
  M.state = {}
end

M.state = M.read()

return M
