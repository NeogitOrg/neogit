local M = {}

local function array_wrap(lines)
  return "[" .. table.concat(lines, ",") .. "]"
end

---Escape any double-quote characters, or escape codes, in the body
---@param json_str string unparsed json
---@param field string The json key to escape the body for
local function escape_field(json_str, field)
  local pattern = ([[(,"%s":")(.-)(",")]]):format(field)

  json_str, _ = json_str:gsub(pattern, function(before, body, after)
    return table.concat({ before, vim.fn.escape(body, [[\"]]), after }, "")
  end)

  return json_str
end

local function raise_error(result, input)
  local msg = vim.split(result, " ")
  local char_index = tonumber(msg[#msg])

  error(
    "Failed to parse log json!: "
    .. result
    .. "\n"
    .. input:sub(char_index - 30, char_index - 1)
    .. "<"
    .. input:sub(char_index, char_index)
    .. ">"
    .. input:sub(char_index + 1, char_index + 30)
  )
end

---Decode a list of json formatted lines into a lua table
---@param lines table
---@return table
function M.decode(lines)
  local json_array = array_wrap(lines)
  json_array = escape_field(json_array, "body")
  json_array = escape_field(json_array, "author_name")
  json_array = escape_field(json_array, "committer_name")
  json_array = escape_field(json_array, "subject")

  local ok, result = pcall(vim.json.decode, json_array, { luanil = { object = true, array = true } })
  if not ok then
    raise_error(result, json_array)
  end

  return result
end

return M
