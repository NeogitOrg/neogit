local M = {}

local record_separator = { dec = "\30", hex_log = "%x1E", hex_ref = "%1E" }
local field_separator = { dec = "\31", hex_log = "%x1F", hex_ref = "%1F" }
local pair_separator = { dec = "\29", hex_log = "%x1D", hex_ref = "%1D" }

-- Matches/captures each key/value pair of fields in a record
-- 1. \31?         - Optionally has a leading field separator (first field won't have this)
-- 2. ([^\31\29]*) - Capture all characters that are not field or pair separators
-- 3. \29          - Pair separator
-- 4. ([^\31]*)    - Capture all characters that are not field separators
-- 5. \31?         - Optionally has a trailing field separator (last field won't have this)
local pattern = "\31?([^\31\29]*)\29([^\31]*)\31?"
local BLANK = ""

local concat = table.concat
local insert = table.insert
local gmatch = string.gmatch
local format = string.format
local split = vim.split
local map = vim.tbl_map

---Parses a record string into a lua table
---@param record_string string
---@return table
local function parse_record(record_string)
  local record = {}

  for key, value in gmatch(record_string, pattern) do
    record[key] = value or BLANK
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
  local lines = concat(lines, "")

  -- Split the string into records, using the record separator character as a delimiter.
  -- If you commit message contains record separator control characters... this won't work,
  -- and you should feel bad about your choices.
  local records = split(lines, record_separator.dec, { trimempty = true })
  return map(parse_record, records)
end

---@param tbl table Key/value pairs to format with delimiters
---@param type string Git log takes a different formatting string for escape literals than for-each-ref.
---@return string
function M.encode(tbl, type)
  local hex = "hex_" .. type
  local out = {}
  for k, v in pairs(tbl) do
    insert(out, format("%s%s%s", k, pair_separator[hex], v))
  end

  return concat(out, field_separator[hex]) .. record_separator[hex]
end

return M
