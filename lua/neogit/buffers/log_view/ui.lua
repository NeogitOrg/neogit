local util = require("neogit.lib.util")

local Commit = require("neogit.buffers.common").CommitEntry
local Graph = require("neogit.buffers.common").CommitGraph

local Ui = require("neogit.lib.ui")
local text = Ui.text
local col = Ui.col
local row = Ui.row

local M = {}

---@param commits CommitLogEntry[]
---@param remotes string[]
---@param args table
---@return table
function M.View(commits, remotes, args)
  args.details = true

  local graph = util.filter_map(commits, function(commit)
    if commit.oid then
      return Commit(commit, remotes, args)
    elseif args.graph then
      return Graph(commit, #commits[1].abbreviated_commit + 1)
    end
  end)

  table.insert(graph, 1, col { row { text("") } })

  table.insert(
    graph,
    col {
      row {
        text.highlight("NeogitGraphBoldBlue")("Type"),
        text.highlight("NeogitGraphBoldCyan")(" + "),
        text.highlight("NeogitGraphBoldBlue")("to show more history"),
      },
    }
  )

  return graph
end

return M
