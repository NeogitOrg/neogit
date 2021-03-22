local function inspect(x)
  print(vim.inspect(x))
end

_G.inspect = inspect

local function map(tbl, f)
  local t = {}
  for k,v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

local function filter(tbl, f)
  local t = {}
  for k,v in pairs(tbl) do
    if f(v) then
      table.insert(t, v)
    end
  end
  return t
end

local function print_tbl(tbl)
  for _,x in pairs(tbl) do
    print("| " .. x)
  end
end

_G.print_tbl = print_tbl

local function tbl_longest_str(tbl)
  local len = 0

  for _,str in pairs(tbl) do
    local str_len = #str
    if str_len > len then
      len = str_len
    end
  end

  return len
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
  local before = vim.fn.reltime()
  local res = f()
  print(name .. " took " .. vim.fn.reltimefloat(vim.fn.reltime(before)) * 1000 .. "ms")
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

local function parse_command_args(...)
  local args = {...}
  local kind = 'tab'
  for _, val in pairs(args) do
    if string.find(val, 'kind=') then
      kind = string.sub(val, 6)
    end
  end
  if kind ~= 'tab' and kind ~= 'floating' and kind ~= 'split' then
    vim.api.nvim_err_writeln('Invalid kind')
    kind = 'tab'
  end
  return kind
end

return {
  inspect = inspect,
  time = time,
  slice = slice,
  map = map,
  tbl_longest_str = tbl_longest_str,
  filter = filter,
  str_right_pad = str_right_pad,
  str_count = str_count,
  create_fold = create_fold,
  get_keymaps = get_keymaps,
  print_tbl = print_tbl,
  split = split,
  parse_command_args = parse_command_args
}

