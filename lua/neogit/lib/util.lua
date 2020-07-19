local function inspect(x)
  print(vim.inspect(x))
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

local function create_fold(first, last)
  vim.api.nvim_command(string.format("%d,%dfold", first, last))
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
  filter = filter,
  str_right_pad = str_right_pad,
  str_count = str_count,
  create_fold = create_fold
}

