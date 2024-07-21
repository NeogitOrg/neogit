local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")

local text = Ui.text
local col = Ui.col
local row = Ui.row

local M = {}

---Parses output of `git stash list` and splits elements into table
M.Stash = Component.new(function(stash)
  local label = table.concat({ "stash@{", stash.idx, "}" }, "")
  return col({
    row({
      text.highlight("Comment")(label),
      text(" "),
      text(stash.message),
    }, {
      virtual_text = {
        { " ", "Constant" },
        { stash.rel_date, "Special" },
      },
    }),
  }, { oid = label })
end)

---@param stashes StashItem[]
---@return table
function M.View(stashes)
  return util.map(stashes, function(stash)
    return M.Stash(stash)
  end)
end

return M
