local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")

local col = Ui.col
local row = Ui.row
local text = Ui.text

local M = {}

local function highlight_ref_name(name)
  return name:match("/") and "String" or "Macro"
end

local function render_line_right(commit)
  if commit.rel_date:match("^%d ") then
    commit.rel_date = " " .. commit.rel_date
  end

  return row {
    text(
      util.str_truncate(commit.author_name, 19, ""), -- TODO: Add a max-width to render
      { highlight = "Constant", align_right = 20, padding_left = 1 }
    ),
    text(commit.rel_date, { highlight = "Special", align_right = 10 })
  }
end

local function render_line_center(commit, max_width)
  local content = {}

  if commit.ref_name ~= "" then
    local ref_name, _ = commit.ref_name:gsub("HEAD %-> ", "")
    local remote_name, local_name = unpack(vim.split(ref_name, ", "))

    if local_name then
      table.insert(content, text(local_name, { highlight = highlight_ref_name(local_name) }))
      table.insert(content, text(" "))

      max_width = max_width - #local_name - 1
    end

    if remote_name then
      table.insert(content, text(remote_name, { highlight = highlight_ref_name(remote_name) }))
      table.insert(content, text(" "))

      max_width = max_width - #remote_name - 1
    end
  end


  table.insert(
    content,
    text(
      util.str_truncate(commit.description[1], max_width),
      { align_right = max_width }
    )
  )

  return row(content)
end

local function highlight_for_type(type)
  if type == "commit" or type == "merge" then
    return "String"
  elseif type == "reset" then
    return "Error"
  elseif type == "checkout" or type == "branch" then
    return "Special"
  elseif type:match("^rebase") or type == "amend" then
    return "Keyword"
  elseif type == "cherry-pick" or type == "revert" then
    return "Boolean"
  elseif type == "pull" or type == "clone" then
    return "Operator"
  else
    return "Operator"
  end
end

M.Entry = Component.new(function(entry, total)
  local date_number, date_quantifier = unpack(vim.split(entry.rel_date, " "))

  local right = row {
    text(util.str_truncate(entry.author_name, 19, ""), { highlight = "Constant", align_right = 20 - #tostring(date_number) }),
    text(date_number .. date_quantifier:sub(1, 1), { highlight = "Special" })
  }

  local spacer = vim.fn.winwidth(0) - (7 + 1 + #tostring(total) + 1 + 16 + #entry.ref_subject) - right:get_width() - 6

  return col {
    row(
      {
        text(entry.oid:sub(1, 7), { highlight = "Comment" }),
        text(" "),
        text(tostring(entry.index), { align_right = #tostring(total) + 1 }),
        text(entry.type, { highlight = highlight_for_type(entry.type), align_right = 16 }),
        text(entry.ref_subject),
        text(string.rep(" ", spacer)),
        right
      },
      { oid = entry.oid }
    )
  }
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
