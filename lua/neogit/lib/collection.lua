local M = {}

function M.keyBy(tbl, key)
  local result = {}
  for _, item in ipairs(tbl) do
    result[item[key]] = item
  end

  return result
end

function M.map(tbl, func)
  local result = {}

  for _, item in ipairs(tbl) do
    table.insert(result, func(item))
  end

  return M(result)
end

function M.filter(tbl, func)
  local result = {}

  for _, item in ipairs(tbl) do
    if func(item) then table.insert(result, item) end
  end

  return M(result)
end

function M.each(tbl, func)
  for _, item in ipairs(tbl) do
    func(item)
  end
end

return setmetatable(M, {
  __call = function (_, tbl)
    return setmetatable(tbl, { __index = M })
  end
})
