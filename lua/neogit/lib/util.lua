local M = {}

---@generic T: any
---@generic U: any
---@param tbl T[]
---@param f Component|fun(v: T): U
---@return U[]
function M.map(tbl, f)
  local t = {}
  for k, v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

---@generic T: any
---@param tbl T[]
---@param f fun(v: T, c: table)
---@return table
function M.collect(tbl, f)
  local t = {}
  for _, v in pairs(tbl) do
    f(v, t)
  end
  return t
end

---@generic T: any
---@param tbl T[][]
---@return T[]
--- Flattens one level of lists
function M.flatten(tbl)
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
function M.flat_map(tbl, f)
  return M.flatten(M.map(tbl, f))
end

---@generic T: any
---@param tbl T[]
---@return T[]
--- Reverses list-like table
function M.reverse(tbl)
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
function M.filter_map(list, f)
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
function M.clamp(value, min, max)
  if value < min then
    return min
  elseif value > max then
    return max
  end
  return value
end

function M.trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function M.deepcopy(o)
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
function M.merge(...)
  local insert = table.insert
  local res = {}
  for _, tbl in ipairs { ... } do
    for _, item in ipairs(tbl) do
      insert(res, item)
    end
  end
  return res
end

function M.range(from, to, step)
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

function M.intersperse(tbl, sep)
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

function M.filter(tbl, f)
  return vim.tbl_filter(f, tbl)
end

---Finds length of longest string in table
---@param tbl table
---@return integer
function M.max_length(tbl)
  local max = 0
  for _, v in ipairs(tbl) do
    if #v > max then
      max = #v
    end
  end
  return max
end

-- function M.print_tbl(tbl)
--   for _, x in pairs(tbl) do
--     print("| " .. x)
--   end
-- end

-- function M.get_keymaps(mode, startswith)
--   local maps = vim.api.nvim_get_keymap(mode)
--   if startswith then
--     return M.filter(maps, function(x)
--       return vim.startswith(x.lhs, startswith)
--     end)
--   else
--     return maps
--   end
-- end

-- function M.time(name, f)
--   local before = os.clock()
--   local res = f()
--   print(name .. " took " .. os.clock() - before .. "ms")
--   return res
-- end

-- function M.time_async(name, f)
--   local before = os.clock()
--   local res = a.run(f())
--   print(name .. " took " .. os.clock() - before .. "ms")
--   return res
-- end

function M.str_min_width(str, len, sep)
  local length = vim.fn.strdisplaywidth(str)
  if length > len then
    return str
  end

  return str .. string.rep(sep or " ", len - length)
end

function M.slice(tbl, s, e)
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

-- function M.str_count(str, target)
--   local count = 0
--   local str_len = #str
--   for i = 1, str_len do
--     if str:sub(i, i) == target then
--       count = count + 1
--     end
--   end
--   return count
-- end

function M.split(str, sep)
  if str == "" then
    return {}
  end
  return vim.split(str, sep)
end

-- function M.split_lines(str)
--   if str == "" then
--     return {}
--   end
--   -- we need \r? to support windows
--   return vim.split(str, "\r?\n")
-- end

function M.str_truncate(str, max_length, trailing)
  trailing = trailing or "..."
  if vim.fn.strdisplaywidth(str) > max_length then
    str = vim.trim(str:sub(1, max_length - #trailing)) .. trailing
  end
  return str
end

function M.str_clamp(str, len, sep)
  return M.str_min_width(M.str_truncate(str, len - 1, ""), len, sep or " ")
end

--- Splits a string every n characters, respecting word boundaries
---@param str string
---@param len integer
---@return table
function M.str_wrap(str, len)
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

function M.parse_command_args(args)
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

---Removes duplicate values from a table
---@param tbl table
---@return table
function M.deduplicate(tbl)
  local res = {}
  for i = 1, #tbl do
    if tbl[i] and not vim.tbl_contains(res, tbl[i]) then
      table.insert(res, tbl[i])
    end
  end
  return res
end

---Removes nil values from a table
---@param tbl table
---@return table
function M.compact(tbl)
  local res = {}
  for i = 1, #tbl do
    if tbl[i] ~= nil then
      table.insert(res, tbl[i])
    end
  end
  return res
end

function M.find(tbl, cond)
  local res
  for i = 1, #tbl do
    if cond(tbl[i]) then
      res = tbl[i]
      break
    end
  end
  return res
end

function M.build_reverse_lookup(tbl)
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
function M.remove_item_from_table(tbl, value)
  local removed = false
  for index, t_value in ipairs(tbl) do
    if vim.deep_equal(t_value, value) then
      table.remove(tbl, index)
      removed = true
    end
  end

  return removed
end

---Checks if both lists contain the same values. This does NOT check ordering.
---@param l1 any[]
---@param l2 any[]
---@return boolean
function M.lists_equal(l1, l2)
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

local special_chars = { "%%", "%(", "%)", "%.", "%+", "%-", "%*", "%?", "%[", "%^", "%$" }
function M.pattern_escape(str)
  for _, char in ipairs(special_chars) do
    str, _ = str:gsub(char, "%" .. char)
  end

  return str
end

function M.pad_right(s, len)
  return s .. string.rep(" ", math.max(len - #s, 0))
end

function M.pad_left(s, len)
  return string.rep(" ", math.max(len - #s, 0)) .. s
end

--- http://lua-users.org/wiki/StringInterpolation
--- @param template string
--- @param values table
--- example:
---   format("${name} is ${value}", {name = "foo", value = "bar"}) )
function M.format(template, values)
  return (template:gsub("($%b{})", function(w)
    return values[w:sub(3, -2)] or w
  end))
end

--- Compute the differences present in a and not in b
---@param a table
---@param b table
---@return table
function M.set_difference(a, b)
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

---comment
---@param s string
---@return string
function M.underscore(s)
  local snakey = function(upper)
    return "_" .. upper:lower()
  end

  local r, _ = s:gsub("%u", snakey):gsub("^_", "")
  return r
end

---Simple timeout function
---@param timeout integer
---@param callback function
---@return uv_timer_t
local function set_timeout(timeout, callback)
  local timer = vim.uv.new_timer()

  timer:start(timeout, 0, function()
    timer:stop()
    timer:close()
    callback()
  end)

  return timer
end

local DEFAULT_TIMEOUT = os.getenv("CI") and 0 or 1000

---Memoize a function's result for a set period of time. Value will be forgotten after specified timeout, or 1 second. Timer resets with each call.
---@param f function Function to memoize
---@param opts table?
---@return function
function M.memoize(f, opts)
  opts = opts or {}

  assert(f, "Cannot memoize without function")

  local cache = {}
  local timer = {}

  return function(...)
    local cwd = vim.uv.cwd()
    assert(cwd, "no cwd")

    local key = vim.inspect { vim.fs.normalize(cwd), ... }

    if cache[key] == nil then
      cache[key] = f(...)
    elseif timer[key] ~= nil then
      timer[key]:stop()
      timer[key]:close()
    end

    timer[key] = set_timeout(opts.timeout or DEFAULT_TIMEOUT, function()
      cache[key] = nil
      timer[key] = nil
    end)

    return cache[key]
  end
end

--- Debounces a function on the trailing edge.
---
--- @generic F: function
--- @param ms number Timeout in ms
--- @param fn F Function to debounce
--- @param hash? integer|fun(...): any Function that determines id from arguments to fn
--- @return F Debounced function.
function M.debounce_trailing(ms, fn, hash)
  local running = {} --- @type table<any,uv_timer_t>

  if type(hash) == "number" then
    local hash_i = hash
    hash = function(...)
      return select(hash_i, ...)
    end
  end

  return function(...)
    local id = hash and hash(...) or true
    if running[id] == nil then
      running[id] = assert(vim.uv.new_timer())
    end

    local timer = running[id]
    local argv = { ... }
    timer:start(ms, 0, function()
      timer:stop()
      running[id] = nil
      vim.schedule_wrap(fn)(unpack(argv, 1, table.maxn(argv)))
    end)
  end
end

---@param value any
---@return table
function M.tbl_wrap(value)
  return type(value) == "table" and value or { value }
end

--- Throttles a function using the first argument as an ID
---
--- If function is already running then the function will be scheduled to run
--- again once the running call has finished.
---
---   fn#1            _/‾\__/‾\_/‾\_____________________________
---   throttled#1 _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\/‾‾‾‾‾‾‾‾‾‾\____________
--
---   fn#2            ______/‾\___________/‾\___________________
---   throttled#2 ______/‾‾‾‾‾‾‾‾‾‾\__/‾‾‾‾‾‾‾‾‾‾\__________
---
---
--- @generic F: function
--- @param fn F Function to throttle
--- @param schedule? boolean
--- @return F throttled function.
function M.throttle_by_id(fn, schedule)
  local scheduled = {} --- @type table<any,boolean>
  local running = {} --- @type table<any,boolean>

  return function(id, ...)
    if scheduled[id] then
      -- If fn is already scheduled, then drop
      return
    end

    if not running[id] or schedule then
      scheduled[id] = true
    end

    if running[id] then
      return
    end

    while scheduled[id] do
      scheduled[id] = nil
      running[id] = true
      pcall(fn, id, ...)
      running[id] = nil
    end
  end
end

-- from: https://stackoverflow.com/questions/48948630/lua-ansi-escapes-pattern
local pattern_1 = "[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]"
local pattern_2 = "[\r\n\04\08]"
local BLANK = ""
local gsub = string.gsub

function M.remove_ansi_escape_codes(s)
  s, _ = gsub(s, pattern_1, BLANK)
  s, _ = gsub(s, pattern_2, BLANK)
  return s
end

--- Safely close a window
---@param winid integer
---@param force boolean
function M.safe_win_close(winid, force)
  local success = M.try(vim.api.nvim_win_close, winid, force)
  if not success then
    pcall(vim.cmd, "b#")
  end
end

function M.weak_table(mode)
  return setmetatable({}, { __mode = mode or "k" })
end

---@param fn fun(...): any
---@param ...any
---@return boolean|any
function M.try(fn, ...)
  local ok, result = pcall(fn, ...)
  if not ok then
    require("neogit.logger").error(result)
    return false
  else
    return result or true
  end
end

return M
