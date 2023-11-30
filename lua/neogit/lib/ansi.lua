local M = {}

-- stylua: ignore
local colors = {
  ["30"] = "Gray",    ["1;30"] = "BoldGray",
  ["31"] = "Red",     ["1;31"] = "BoldRed",
  ["32"] = "Green",   ["1;32"] = "BoldGreen",
  ["33"] = "Yellow",  ["1;33"] = "BoldYellow",
  ["34"] = "Blue",    ["1;34"] = "BoldBlue",
  ["35"] = "Purple",  ["1;35"] = "BoldPurple",
  ["36"] = "Cyan",    ["1;36"] = "BoldCyan",
  ["37"] = "White",   ["1;37"] = "BoldWhite",
}

local mark = "%"

---Parses a string with ansi-escape codes (colors) into a table
---@param str string
function M.parse(str, opts)
  if str == "" then
    return
  end

  local graph, oid = unpack(vim.split(str, " \30", { trimempty = true }))
  local colored = {}

  local parsed, _ = graph:gsub("(\27%[[;%d]*m.-\27%[m)", function(match)
    local color, text = match:match("\27%[([;%d]*)m(.-)\27%[m")

    if opts.recolor then
      color = "35"
    end

    table.insert(colored, { text = text, color = colors[color], oid = oid })
    return mark
  end)

  local out = {}
  for g in parsed:gmatch(".") do
    if g == mark then
      assert(not vim.tbl_isempty(colored), "ANSI Parser didn't construct all graph parts: " .. str)
      table.insert(out, table.remove(colored, 1))
    else
      table.insert(out, { text = g, color = "Gray", oid = oid })
    end
  end

  assert(vim.tbl_isempty(colored), "ANSI Parser didn't consume all graph parts")

  return out
end

return M
