local Ui = require 'neogit.lib.ui'
local Component = require 'neogit.lib.ui.component'
local util = require 'neogit.lib.util'

local col = Ui.col
local row = Ui.row
local text = Ui.text

local map = util.map

local M = {}

-- * commit e0a6cd38f783a6028cf1f18a72fdbb761ad2fd62 (HEAD -> commit-inspection, origin/commit-inspection)
-- | Author:     TimUntersberger <timuntersberger2@gmail.com>
-- | AuthorDate: Sat May 29 19:31:30 2021 +0200
-- | Commit:     TimUntersberger <timuntersberger2@gmail.com>
-- | CommitDate: Sat May 29 19:31:30 2021 +0200
-- |
-- |     feat: improve commit view and ui lib
-- |

M.Commit = Component.new(function(commit, show_graph)
  return col {
    row { 
      text(show_graph 
        and ("* "):rep(commit.level + 1) 
        or "* ", { highlight = "Character" }), 
      text(commit.oid:sub(1, 7), { highlight = "Number" }), 
      text " ", 
      text(commit.description[1]) 
    },
    col.hidden(true).padding_left((commit.level + 1) * 2) {
      row {
        text "Author:     ",
        text(commit.author_name),
        text " <",
        text(commit.author_date),
        text ">"
      },
      row {
        text "AuthorDate: ",
        text(commit.author_date)
      },
      row {
        text "Commit:     ",
        text(commit.committer_name),
        text " <",
        text(commit.committer_date),
        text ">"
      },
      row {
        text "CommitDate: ",
        text(commit.committer_date)
      },
      text " ",
      col(map(commit.description, text), { padding_left = 4 })
    }
  }
end)

function M.LogView(data, show_graph)
  return map(data, function(row)
    return M.Commit(row, show_graph) 
  end)
end

return M
