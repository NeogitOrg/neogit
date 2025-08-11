local popup = require("neogit.lib.popup")
-- local config = require("neogit.config")
local actions = require("neogit.popups.margin.actions")

local M = {}

-- TODO: Implement various flags/switches

function M.create(env)
  local p = popup
    .builder()
    :name("NeogitMarginPopup")
    -- :option("n", "max-count", "256", "Limit number of commits", { default = "256", key_prefix = "-" })
    -- :switch("o", "topo", "Order commits by", {
    --   cli_suffix = "-order",
    --   options = {
    --     { display = "", value = "" },
    --     { display = "topo", value = "topo" },
    --     { display = "author-date", value = "author-date" },
    --     { display = "date", value = "date" },
    --   },
    -- })
    -- :switch("g", "graph", "Show graph", {
    --   enabled = true,
    --   internal = true,
    --   incompatible = { "reverse" },
    --   dependent = { "color" },
    -- })
    -- :switch_if(
    --   config.values.graph_style == "ascii" or config.values.graph_style == "kitty",
    --   "c",
    --   "color",
    --   "Show graph in color",
    --   { internal = true, incompatible = { "reverse" } }
    -- )
    :switch(
      "d",
      "decorate",
      "Show refnames",
      { enabled = true, internal = true }
    )
    :group_heading("Refresh")
    :action_if(env.buffer, "g", "buffer", actions.refresh_buffer(env.buffer), { persist_popup = true })
    :new_action_group("Margin")
    :action("L", "toggle visibility", actions.toggle_visibility, { persist_popup = true })
    :action("l", "cycle style", actions.cycle_date_style, { persist_popup = true })
    :action("d", "toggle details", actions.toggle_details, { persist_popup = true })
    :action("x", "toggle shortstat", actions.log_current, { persist_popup = true })
    :build()

  p:show()

  return p
end

return M
