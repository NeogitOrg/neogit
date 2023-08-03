local api = vim.api

api.nvim_create_user_command("Neogit", function(o)
  local neogit = require("neogit")
  neogit.open(require("neogit.lib.util").parse_command_args(o.fargs))
end, {
  nargs = "*",
  desc = "Open Neogit",
  complete = function(arglead)
    local neogit = require("neogit")
    return neogit.complete(arglead)
  end,
})

api.nvim_create_user_command("NeogitMessages", function()
  for _, message in ipairs(require("neogit.lib.notification").get_history()) do
    print(string.format("[%s]: %s", message.kind, table.concat(message.content, " - ")))
  end
end, {
  nargs = "*",
  desc = "Prints neogit message history",
})

api.nvim_create_user_command("NeogitResetState", function()
  require("neogit.lib.state")._reset()
end, { nargs = "*", desc = "Reset any saved flags" })
