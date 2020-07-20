local function inspect(x)
  print(vim.inspect(x))
end

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

local function time(name, f)
  local before = vim.fn.reltime()
  f()
  print(name .. " took " .. vim.fn.reltimefloat(vim.fn.reltime(before)) * 100 .. "ms")
end

local function str_right_pad(str, len, sep)
  return str .. sep:rep(len - #str)
end

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

local function create_fold(buf, first, last)
  if not buf or buf == 0 then
    vim.api.nvim_command(string.format("%d,%dfold", first, last))
  else
    vim.api.nvim_command(string.format(buf .. "bufdo %d,%dfold", first, last))
  end
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

return {
  inspect = inspect,
  time = time,
  slice = slice,
  map = map,
  tbl_longest_str = tbl_longest_str,
  filter = filter,
  str_right_pad = str_right_pad,
  str_count = str_count,
  create_fold = create_fold
}

