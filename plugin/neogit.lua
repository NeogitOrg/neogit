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

api.nvim_create_user_command("NeogitResetState", function()
  require("neogit.lib.state")._reset()
end, { nargs = "*", desc = "Reset any saved flags" })
