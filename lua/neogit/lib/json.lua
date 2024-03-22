local M = {}

local record_separator = { dec = "\30", hex = "%x1E" }
local field_separator = { dec = "\31", hex = "%x1F" }
local pair_separator = { dec = "\29", hex = "%x1D" }

---Decode a list of json formatted lines into a lua table
---@param lines table
---@return table
function M.decode(lines)
  if not lines[1] then
    return {}
  end

  local lines = table.concat(lines, "")
  local records = vim.tbl_map(function(record)
    local fields = vim.tbl_map(function(field)
      return vim.split(field, pair_separator.dec, { trimempty = true })
    end, vim.split(record, field_separator.dec, { trimempty = true }))

    local output = {}
    for _, field in ipairs(fields) do
      local key, value = unpack(field)
      output[key] = value or ""
    end

    return output
  end, vim.split(lines, record_separator.dec, { trimempty = true }))

  return records
end

---@param tbl table Key/value pairs to encode as json
---@return string
function M.encode(tbl)
  local out = {}
  for k, v in pairs(tbl) do
    table.insert(out, string.format("%s%s%s", k, pair_separator.hex, v))
  end

  return table.concat(out, field_separator.hex) .. record_separator.hex
end

return M
