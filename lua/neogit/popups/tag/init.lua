local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.tag.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeogitTagPopup")
    :arg_heading("Arguments")
    :switch("f", "force", "Force", { persisted = false })
    :switch("a", "annotate", "Annotate")
    :switch("s", "sign", "Sign")
    :option("u", "local-user", "", "Sign as", { key_prefix = "-" })
    :group_heading("Create")
    :action("t", "tag", actions.create_tag)
    :action("r", "release")
    :new_action_group("Do")
    :action("x", "delete", actions.delete)
    :action("p", "prune", actions.prune)
    :env(env)
    :build()

  p:show()

  return p
end

return M
