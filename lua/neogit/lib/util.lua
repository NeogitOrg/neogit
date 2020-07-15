local function inspect(x)
  print(vim.inspect(x))
end

local function str_right_pad(str, len, sep)
  return str .. sep:rep(len - #str)
end

return {
  inspect = inspect,
  str_right_pad = str_right_pad
}

