local M = {}

local record_separator = { dec = "\30", hex = "%x1E" }
local field_separator = { dec = "\31", hex = "%x1F" }
local pair_separator = { dec = "\29", hex = "%x1D" }

-- Matches/captures each key/value pair of fields in a record
-- 1. \31?         - Optionally has a leading field separator (first field won't have this)
-- 2. ([^\31\29]*) - Capture all characters that are not field or pair separators
-- 3. \29          - Pair separator
-- 4. ([^\31]*)    - Capture all characters that are not field separators
-- 5. \31?         - Optionally has a trailing field separator (last field won't have this)
local pattern = "\31?([^\31\29]*)\29([^\31]*)\31?"

---Parses a record string into a lua table
---@param record_string string
---@return table
local function parse_record(record_string)
  local record = {}

  for key, value in string.gmatch(record_string, pattern) do
    record[key] = value or ""
  end

  return record
end

---Decode a list of delimited lines into lua tables
---@param lines string[]
---@return table
function M.decode(lines)
  if not lines[1] then
    return {}
  end

  -- join lines into one string, since a record could potentially span multiple
  -- lines if the subject/body fields contain \n or \r characters.
  local lines = table.concat(lines, "")

  -- Split the string into records, using the record separator character as a delimiter.
  -- If you commit message contains record separator control characters... this won't work,
  -- and you should feel bad about your choices.
  return vim.tbl_map(parse_record, vim.split(lines, record_separator.dec, { trimempty = true }))
end

---@param tbl table Key/value pairs to format with delimiters
---@return string
function M.encode(tbl)
  local out = {}
  for k, v in pairs(tbl) do
    table.insert(out, string.format("%s%s%s", k, pair_separator.hex, v))
  end

  return table.concat(out, field_separator.hex) .. record_separator.hex
end

return M
