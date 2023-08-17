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

---Parses a string with ansi-escape codes (colors) into a table
---@param str string
function M.parse(str, opts)
  local colored = {}
  local idx = 1

  local parsed, _ = str:gsub("(\27%[[;%d]*m.-\27%[m)", function(match)
    local color, text = match:match("\27%[([;%d]*)m(.-)\27%[m")

    if opts.recolor then
      color = "35"
    end

    colored[tostring(idx)] = { text = text, color = colors[color] }
    idx = idx + 1

    return idx - 1
  end)

  local out = {}
  for g in parsed:gmatch(".") do
    if g:match("%d") then
      table.insert(out, colored[g])
    else
      table.insert(out, { text = g, color = "Gray" })
    end
  end

  return out
end

return M
