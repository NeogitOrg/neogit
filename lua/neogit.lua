local config = require("neogit.config")
local lib = require("neogit.lib")
local signs = require("neogit.lib.signs")
local status = require("neogit.status")

local neogit = {
  lib = require("neogit.lib"),
  popups = require("neogit.popups"),
  config = config,
  status = status,
  get_repo = function()
    return status.repo
  end,
  cli = lib.git.cli,
  get_log_file_path = function()
    return vim.fn.stdpath("cache") .. "/neogit.log"
  end,
  notif = require("neogit.lib.notification"),
  open = function(opts)
    opts = opts or {}
    if opts[1] ~= nil then
      local popup_name = opts[1]
      local popup = require("neogit.popups." .. popup_name)

      if popup == nil then
        vim.api.nvim_err_writeln("Invalid popup '" .. popup_name .. "'")
      else
        popup.create()
      end
    else
      status.create(opts.kind or "tab")
    end
  end,
  reset = status.reset,
  get_config = function()
    return config.values
  end,
  dispatch_reset = status.dispatch_reset,
  refresh = status.refresh,
  dispatch_refresh = status.dispatch_refresh,
  refresh_viml_compat = status.refresh_viml_compat,
  close = status.close,
  setup = function(opts)
    if opts ~= nil then
      config.values = vim.tbl_deep_extend("force", config.values, opts)
    end
    if not config.values.disable_signs then
      signs.setup()
    end
  end
}

neogit.setup()

return neogit
