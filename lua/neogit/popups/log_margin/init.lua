local popup = require("neogit.lib.popup")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitLogMarginPopup")
    :option("n", "max-count", "256", "Limit number of commits", { default = "256" })
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
