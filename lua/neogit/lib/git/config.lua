local logger = require("neogit.logger")
local a = require("plenary.async")
local uv = require("neogit.lib.uv")

local M = {}

function M.get(key)
  -- internal, no CLI
end

function M.set(key, value)
  -- cli
end

function M.unset(key)
   -- cli
end

function M.update_config(state)
  local cli = require("neogit.lib.git.cli")
  local root = cli.git_root()
  if root == "" then
    return
  end

  local config = {}

  local _, config_file = a.uv.fs_stat(root .. "/.git/config")
  if not config_file then
    logger.error("[Config] Could not stat .git/config")
    return
  end

  local err, config_content = uv.read_file(config_file)
  if err then
    logger.error("[Config] Could not read .git/config - " .. err)
    return
  end

  P(config_content)

  state.config = config
end

M.register = function(meta)
  meta.update_config = M.update_config
end

return M
