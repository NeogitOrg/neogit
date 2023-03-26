local cli = require("neogit.lib.git.cli")

local M = {}

local function get_type_of_value(value)
  if value == "true" or value == "false" then
    return "boolean"
  elseif tonumber(value) then
    return "number"
  else
    return "string"
  end
end

local function config()
  local result = {}

  for _, option in ipairs(cli.config.list.call_sync():trim().stdout) do
    local key, value = option:match([[^(.-)=(.*)$]])
    result[key] = { value = value, type = get_type_of_value(value) }
  end

  return result
end

function M.get(key)
  return config()[key]
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
  cli.config.add(key, value).call_sync()
end

function M.unset(key)
  cli.config.unset(key).call_sync()
end

return M
