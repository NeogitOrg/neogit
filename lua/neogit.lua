local config = require("neogit.config")
local signs = require("neogit.lib.signs")

local neogit = {
  lib = require("neogit.lib"),
  popups = require("neogit.popups"),
  status = require("neogit.status"),
  config = config,
  setup = function(opts)
    config.values = vim.tbl_deep_extend("force", config.values, opts)
    if not config.values.disable_signs then
      signs.setup()
    end
  end
}

return neogit
