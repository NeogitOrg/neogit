local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")

local text = Ui.text
local col = Ui.col
local row = Ui.row

local util = require("neogit.lib.util")

local StashEntry = require("neogit.lib.git.stash").StashEntry

local M = {}

---Parses output of `git stash list` and splits elements into table
local M.Stash = Component.new(function(stashes)
  local children = {}
  for _, stash in ipairs(stashes) do
    -- Split raw output as the stash_id is useful later.
    local raw = util.split(stash, ":")
    local stash_id = raw[1] -- stash@{<num>}
    local stash_msg = raw[2] .. ":" .. raw[3] -- WIP on <branch>: <commit> <msg>"
    local entry = row({
      text(stash_id), text(stash_msg)
    })

    table.insert(children, entry)
  end

  return col(children)
end)

---@param stashes StashEntry[]
---@return table
function M.View(stashes)
  return M.Stash(stashes)
end

return M
