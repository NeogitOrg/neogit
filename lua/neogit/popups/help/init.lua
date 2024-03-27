local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.help.actions")

local M = {}

-- TODO: Better alignment for labels, keys
function M.create(env)
  local p = popup.builder():name("NeogitHelpPopup"):group_heading("Commands")

  local popups = actions.popups(env)
  for i, cmd in ipairs(popups) do
    p = p:action(cmd.keys, cmd.name, cmd.fn)

    if i == math.floor(#popups / 2) then
      p = p:new_action_group()
    end
  end

  p = p:new_action_group():new_action_group("Applying changes")
  for _, cmd in ipairs(actions.actions()) do
    p = p:action(cmd.keys, cmd.name, cmd.fn)
  end

  p = p:new_action_group():new_action_group("Essential commands")
  for _, cmd in ipairs(actions.essential()) do
    p = p:action(cmd.keys, cmd.name, cmd.fn)
  end

  p = p:build()
  p:show()

  return p
end

return M
