local M = {}

function M.new(initial_value)
  initial_value = initial_value or {}
  if type(initial_value) ~= "table" then 
    error("Initial value must be a table", 2) 
  end

  return setmetatable(initial_value, { __index = M })
end

function M.append(tbl, data)
  if type(data) == 'string' then table.insert(tbl, data)
  elseif type(data) == 'table' then
    for _, r in ipairs(data) do 
      table.insert(tbl, r) 
    end
  else 
    error('invalid data type: ' .. type(data), 2) 
  end
  return tbl
end

return M
