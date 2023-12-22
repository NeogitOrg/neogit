local M = {}
local diffview = require("neogit.integrations.diffview")

-- aka "dwim" = do what I mean
function M.this(popup)
  popup:close()

  if popup.state.env.section and popup.state.env.item then
    diffview.open(popup.state.env.section.name, popup.state.env.item.name, {
      only = true,
    })
  elseif popup.state.env.section then
    diffview.open(popup.state.env.section.name, nil, { only = true })
  end
end

function M.worktree(popup)
  popup:close()
  diffview.open()
end

return M
