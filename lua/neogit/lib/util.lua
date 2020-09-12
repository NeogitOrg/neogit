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

local function get_path_dir(path)
  local dir = path
  local prev = ''
  while dir ~= prev do
    local git_dir = dir .. '/.git'
    local dir_info = vim.loop.fs_stat(git_dir)
    if dir_info and dir_info['type'] == 'directory' then
      local obj_dir_info = vim.loop.fs_stat(git_dir .. '/objects')
      if obj_dir_info and obj_dir_info['type'] == 'directory' then
        local refs_dir_info = vim.loop.fs_stat(git_dir .. '/refs')
        if refs_dir_info and refs_dir_info['type'] == 'directory' then
          local head_info = vim.loop.fs_stat(git_dir .. '/HEAD')
          if head_info and head_info.size > 10 then return git_dir end
        end
      end
    elseif dir_info and dir_info['type'] == 'file' then
      local reldir = vim.fn.readfile(git_dir)[1] or ''
      if string.find(reldir, '^gitdir: ') then
        return vim.fn.simplify(dir .. '/' .. string.sub(reldir, 9))
      end
    end

    prev = dir
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  return ''
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
  get_path_dir = get_path_dir,
  get_keymaps = get_keymaps,
  print_tbl = print_tbl,
}

