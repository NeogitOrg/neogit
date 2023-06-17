local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")

local col = Ui.col
local row = Ui.row
local text = Ui.text

local M = {}

local function highlight_for_type(type)
  if type == "commit" or type == "merge" then
    return "String" -- Green
  elseif type == "reset" then
    return "Error" -- Red
  elseif type == "checkout" or type == "branch" then
    return "Special" -- Blue
  elseif type == "cherry-pick" or type == "revert" then
    return "Boolean" -- Yellow
  elseif type:match("^rebase") or type == "amend" then
    return "Keyword" -- Purple
  else -- pull, clone, unknown
    return "Operator" -- Cyan
  end
end

M.Entry = Component.new(function(entry, total)
  local date_number, date_quantifier = unpack(vim.split(entry.rel_date, " "))

  return col({
    row({
      text(entry.oid:sub(1, 7), { highlight = "Comment" }),
      text(" "),
      text(tostring(entry.index), { align_right = #tostring(total) + 1 }),
      text(entry.type, { highlight = highlight_for_type(entry.type), align_right = 16 }),
      text(entry.ref_subject),
    }, {
      virtual_text = {
        { " ", "Constant" },
        -- { util.str_clamp(entry.author_name, 20 - #tostring(date_number)), "Constant" },
        { date_number .. date_quantifier:sub(1, 1), "Special" },
      },
    }),
  }, { oid = entry.oid })
end)

---@param entries ReflogEntry[]
---@return table
function M.View(entries)
  local total = #entries
  return util.map(entries, function(entry)
    return M.Entry(entry, total)
  end)
end

return M
