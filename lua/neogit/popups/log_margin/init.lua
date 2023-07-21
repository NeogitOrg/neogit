local popup = require("neogit.lib.popup")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitLogMarginPopup")
    :switch("n", "max-count", "Prune deleted branches")
    :switch("o", "order", "Order commits by")
    :switch("g", "graph", "Show graph")
    :switch("c", "color", "Show graph in color")
    :switch("d", "refnames", "Show refnames")
    :group_heading("Margin")
    :action("L", "visibility", "toggle visibility")
    :action("l", "style", "cycle style")
    :action("d", "details", "toggle details")
    :action("x", "shortstat", "toggle shortstat")
    :build()

  p:show()

  return p
end

return M
