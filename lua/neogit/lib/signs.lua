local config = require("neogit.config")
local M = {}

local signs = {
  CommitViewDescription = { linehl = "NeogitHunkHeader" },
  CommitViewHeader = { linehl = "NeogitCommitViewHeader" },
  DiffAdd = { linehl = "NeogitDiffAdd" },
  DiffAddHighlight = { linehl = "NeogitDiffAddHighlight" },
  DiffContext = { linehl = "NeogitDiffContext" },
  DiffContextHighlight = { linehl = "NeogitDiffContextHighlight" },
  DiffDelete = { linehl = "NeogitDiffDelete" },
  DiffDeleteHighlight = { linehl = "NeogitDiffDeleteHighlight" },
  DiffHeader = { linehl = "NeogitDiffHeader" },
  HunkHeader = { linehl = "NeogitHunkHeader" },
  HunkHeaderHighlight = { linehl = "NeogitHunkHeaderHighlight" },
  LogViewCursorLine = { linehl = "NeogitCursorLine" },
  RebaseDone = { linehl = "NeogitRebaseDone" },
}

function M.setup()
  if not config.values.disable_signs then
    for key, val in pairs(config.values.signs) do
      if key == "hunk" or key == "item" or key == "section" then
        vim.fn.sign_define("NeogitClosed:" .. key, { text = val[1] })
        vim.fn.sign_define("NeogitOpen:" .. key, { text = val[2] })
      end
    end
  end

  for key, val in pairs(signs) do
    vim.fn.sign_define("Neogit" .. key, val)
  end
end

return M
