local a = require("plenary.async")
local uv = vim.loop

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

---@generic T: any
---@param tbl T[][]
---@return T[]
--- Flattens one level of lists
local function flatten(tbl)
  local t = {}

  for _, v in ipairs(tbl) do
    for _, v in ipairs(v) do
      table.insert(t, v)
    end
  end

  return t
end

---@generic T: any
---@generic U: any
---@param tbl T[]
---@param f fun(v: T): U
---@return U[]
local function flat_map(tbl, f)
  return flatten(map(tbl, f))
end

---@generic T: any
---@param tbl T[]
---@return T[]
--- Reverses list-like table
local function reverse(tbl)
  local t = {}
  local c = #tbl + 1

  for i, v in ipairs(tbl) do
    t[c - i] = v
  end

  return t
end

---@generic T: any
---@generic U: any
---@param list T[]
---@param f fun(v: T): U|nil
---@return U[]
local function filter_map(list, f)
  local t = {}
  for _, v in ipairs(list) do
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

--- Splits a string every n characters, respecting word boundaries
---@param str string
---@param len integer
---@return table
local function str_wrap(str, len)
  if #str < len then
    return { str }
  end

  local s = {}
  local tmp = {}

  local words = vim.split(str, " ")
  local line_length = 0
  while true do
    if #words == 0 then
      table.insert(s, table.concat(tmp, " "))
      break
    end

    local word = table.remove(words, 1)
    if line_length + #word + 1 > len then
      table.insert(s, table.concat(tmp, " "))
      tmp = {}

      table.insert(tmp, word)
      line_length = #word
    else
      table.insert(tmp, word)
      line_length = line_length + #word + 1
    end
  end

  return s
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

---Removes the given value from the table
---@param tbl table
---@param value any
local function remove_item_from_table(tbl, value)
  for index, t_value in ipairs(tbl) do
    if vim.deep_equal(t_value, value) then
      table.remove(tbl, index)
    end
  end
end

---Checks if both lists contain the same values. This does NOT check ordering.
---@param l1 any[]
---@param l2 any[]
---@return boolean
local function lists_equal(l1, l2)
  if #l1 ~= #l2 then
    return false
  end

  for _, value in ipairs(l1) do
    if not vim.tbl_contains(l2, value) then
      return false
    end
  end

  return true
end

local function pad_right(s, len)
  return s .. string.rep(" ", math.max(len - #s, 0))
end

--- Debounces a function on the trailing edge.
---
--- @generic F: function
--- @param ms number Timeout in ms
--- @param fn F Function to debounce
--- @return F Debounced function.
local function debounce_trailing(ms, fn)
  local timer = assert(uv.new_timer())
  return function(...)
    local argv = { ... }
    timer:start(ms, 0, function()
      timer:stop()
      fn(unpack(argv))
    end)
  end
end

--- http://lua-users.org/wiki/StringInterpolation
--- @param template string
--- @param values table
--- example:
---   format("${name} is ${value}", {name = "foo", value = "bar"}) )
local function format(template, values)
  return (template:gsub("($%b{})", function(w)
    return values[w:sub(3, -2)] or w
  end))
end

--- Compute the differences present in a and not in b
---@param a table
---@param b table
---@return table
local function set_difference(a, b)
  local result = {}
  for _, x in ipairs(a) do
    local found = false
    for _, y in ipairs(b) do
      if x == y then
        found = true
        break
      end
    end
    if not found then
      table.insert(result, x)
    end
  end
  return result
end

return {
  time = time,
  time_async = time_async,
  clamp = clamp,
  slice = slice,
  map = map,
  flatten = flatten,
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
  remove_item_from_table = remove_item_from_table,
  lists_equal = lists_equal,
  pad_right = pad_right,
  reverse = reverse,
  flat_map = flat_map,
  str_wrap = str_wrap,
  debounce_trailing = debounce_trailing,
  format = format,
  set_difference = set_difference,
}
