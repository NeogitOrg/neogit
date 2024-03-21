local logger = require("neogit.logger")
local M = {}

local function parse_line(line)
  return assert(loadstring(string.format("return { %s }", line)))()
end

---Decode a list of json formatted lines into a lua table
---@param lines table
---@return table
function M.decode(lines)
  if not lines[1] then
    return {}
  end

  local result = {}
  for _, line in ipairs(lines) do
    table.insert(result, parse_line(line))
  end

  logger.debug(result)
  return result
end

---@param tbl table Key/value pairs to encode as json
---@return string
function M.encode(tbl)
  local out = {}
  for k, v in pairs(tbl) do
    table.insert(out, string.format([=[["%s"]=[===[%s]===]]=], k, v))
  end

  return table.concat(out, ",")
end

return M
