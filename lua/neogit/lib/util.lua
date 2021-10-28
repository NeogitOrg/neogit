local a = require 'plenary.async'

local function map(tbl, f)
  local t = {}
  for k,v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

---@param value number
---@param min number
---@param max number
---@return number
local function clamp(value, min, max)
  if value < min then
    return min
  elseif value > max then
    return max
  end
  return value
end

local function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function deepcopy(o)
  local mt = getmetatable(o)
  local copy = vim.deepcopy(o)

  if mt then
    setmetatable(copy, mt)
  end

  return copy
end

local function range(from, to, step)
  local step = step or 1
  local t = {}
  if to == nil then
    to = from
    from = 1
  end
  for i=from, to, step do
    table.insert(t, i)
  end
  return t
end

local function intersperse(tbl, sep)
  local t = {}
  local len = #tbl
  for i=1,len do
    table.insert(t, tbl[i])

    if i ~= len then
      table.insert(t, sep)
    end
  end
  return t
end

local function filter(tbl, f)
  return vim.tbl_filter(f, tbl)
end

local function print_tbl(tbl)
  for _,x in pairs(tbl) do
    print("| " .. x)
  end
end

local function get_keymaps(mode, startswith)
  local maps = vim.api.nvim_get_keymap(mode)
  if startswith then
    return filter(
      maps,
      function (x)
        return vim.startswith(x.lhs, startswith)
      end
    )
  else
    return maps
  end
end

local function time(name, f)
  local before = os.clock()
  local res = f()
  print(name .. " took " .. os.clock() - before .. "ms")
  return res
end

local function time_async(name, f)
  local before = os.clock()
  local res = a.run(f())
  print(name .. " took " .. os.clock() - before .. "ms")
  return res
end

local function str_right_pad(str, len, sep)
  return str .. sep:rep(len - #str)
end

local function slice (tbl, s, e)
  local pos, new = 1, {}

  if e == nil then
    e = #tbl
  end

  for i = s, e do
    new[pos] = tbl[i]
    pos = pos + 1
  end

  return new
end

local function str_count(str, target)
  local count = 0
  local str_len = #str
  for i=1,str_len do
    if str:sub(i, i) == target then
      count = count + 1
    end
  end
  return count
end

local function split(str, sep)
  if str == "" then return {} end
  return vim.split(str, sep)
end

local function split_lines(str)
  if str == "" then return {} end
  -- we need \r? to support windows
  return vim.split(str, '\r?\n')
end

local function parse_command_args(...)
  local args = {...}
  local tbl = {}

  for _, val in pairs(args) do
    local parts = vim.split(val, "=")
    if #parts == 1 then
      table.insert(tbl, parts[1])
    else
      tbl[parts[1]] = parts[2]
    end
  end

  return tbl
end

return {
  time = time,
  time_async = time_async,
  clamp = clamp,
  slice = slice,
  map = map,
  range = range,
  filter = filter,
  str_right_pad = str_right_pad,
  str_count = str_count,
  get_keymaps = get_keymaps,
  print_tbl = print_tbl,
  split = split,
  intersperse = intersperse,
  split_lines = split_lines,
  deepcopy = deepcopy,
  trim = trim,
  parse_command_args = parse_command_args
}

