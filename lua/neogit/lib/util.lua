local a = require("plenary.async")

---@generic T: any
---@generic U: any
---@param tbl T[]
---@param f fun(v: T): U
---@return U[]
local function map(tbl, f)
  local t = {}
  for k, v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

---@param tbl any[]
---@param f fun(v: any) -> any|nil
---@return any[]
local function filter_map(tbl, f)
  local t = {}
  for _, v in ipairs(tbl) do
    v = f(v)
    if v ~= nil then
      table.insert(t, v)
    end
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

--- Merge multiple 1-dimensional list-like tables into one, preserving order
---@param ... table
---@return table
local function merge(...)
  local res = {}
  for _, tbl in ipairs { ... } do
    for _, item in ipairs(tbl) do
      table.insert(res, item)
    end
  end
  return res
end

local function range(from, to, step)
  local step = step or 1
  local t = {}
  if to == nil then
    to = from
    from = 1
  end
  for i = from, to, step do
    table.insert(t, i)
  end
  return t
end

local function intersperse(tbl, sep)
  local t = {}
  local len = #tbl
  for i = 1, len do
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
  for _, x in pairs(tbl) do
    print("| " .. x)
  end
end

local function get_keymaps(mode, startswith)
  local maps = vim.api.nvim_get_keymap(mode)
  if startswith then
    return filter(maps, function(x)
      return vim.startswith(x.lhs, startswith)
    end)
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

local function str_min_width(str, len, sep)
  local length = vim.fn.strdisplaywidth(str)
  if length > len then
    return str
  end

  return str .. string.rep(sep or " ", len - length)
end

local function slice(tbl, s, e)
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
  for i = 1, str_len do
    if str:sub(i, i) == target then
      count = count + 1
    end
  end
  return count
end

local function split(str, sep)
  if str == "" then
    return {}
  end
  return vim.split(str, sep)
end

local function split_lines(str)
  if str == "" then
    return {}
  end
  -- we need \r? to support windows
  return vim.split(str, "\r?\n")
end

local function str_truncate(str, max_length, trailing)
  trailing = trailing or "..."
  if vim.fn.strdisplaywidth(str) > max_length then
    str = vim.trim(str:sub(1, max_length - #trailing)) .. trailing
  end
  return str
end

local function str_clamp(str, len, sep)
  return str_min_width(str_truncate(str, len - 1, ""), len, sep or " ")
end

local function parse_command_args(args)
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

local function pattern_escape(str)
  local special_chars = { "(", ")", ".", "%", "+", "-", "*", "?", "[", "^", "$" }
  for _, char in ipairs(special_chars) do
    str, _ = str:gsub("%" .. char, "%%" .. char)
  end

  return str
end

local function deduplicate(tbl)
  local res = {}
  for i = 1, #tbl do
    if tbl[i] and not vim.tbl_contains(res, tbl[i]) then
      table.insert(res, tbl[i])
    end
  end
  return res
end

local function find(tbl, cond)
  local res
  for i = 1, #tbl do
    if cond(tbl[i]) then
      res = tbl[i]
      break
    end
  end
  return res
end

local function build_reverse_lookup(tbl)
  local result = {}
  for i, v in ipairs(tbl) do
    table.insert(result, v)
    result[v] = i
  end
  return result
end

local function pad_right(s, len)
  return s .. string.rep(" ", math.max(len - #s, 0))
end

return {
  time = time,
  time_async = time_async,
  clamp = clamp,
  slice = slice,
  map = map,
  filter_map = filter_map,
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
  parse_command_args = parse_command_args,
  pattern_escape = pattern_escape,
  deduplicate = deduplicate,
  build_reverse_lookup = build_reverse_lookup,
  str_truncate = str_truncate,
  find = find,
  merge = merge,
  str_min_width = str_min_width,
  str_clamp = str_clamp,
  pad_right = pad_right,
}
