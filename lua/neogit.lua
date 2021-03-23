local config = require("neogit.config")

local neogit = {
  lib = require("neogit.lib"),
  popups = require("neogit.popups"),
  status = require("neogit.status"),
  config = config,
  setup = function(opts)
    config.values = vim.tbl_deep_extend("force", config.values, opts)
  end
}

return neogit
