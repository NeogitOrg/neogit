local popup = require("neogit.lib.popup")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitLogMarginPopup")
    :config("n", "neogit.status.commits")
    :config("o", "neogit.status.order", {
      prefix = "--",
      suffix = "-order",
      options = {
        { display = "", value = "" },
        { display = "topo", value = "--topo" },
        { display = "author-date", value = "--author-date" },
        { display = "date", value = "--date" },
      },
    })
    :config("g", "neogit.status.graph")
    :config("c", "neogit.status.color")
    :config("d", "neogit.status.refnames")
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
