local config = require("neogit.config")
local signs = require("neogit.lib.signs")
local status = require("neogit.status")

local setup_called = false

local neogit = {
  lib = require("neogit.lib"),
  popups = require("neogit.popups"),
  config = config,
  status = status,
  notif = require("neogit.lib.notification"),
  open = function(opts)
    if not setup_called then
      error("You have to call the setup function before using the plugin")
    end
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
  setup = function(opts)
    setup_called = true
    vim.cmd("hi NeogitNotificationInfo guifg=#80ff95")
    vim.cmd("hi NeogitNotificationWarning guifg=#fff454")
    vim.cmd("hi NeogitNotificationError guifg=#c44323")
    config.values = vim.tbl_deep_extend("force", config.values, opts)
    if not config.values.disable_signs then
      signs.setup()
    end
  end
}

return neogit
