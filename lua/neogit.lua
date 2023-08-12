local config = require("neogit.config")
local a = require("plenary.async")
local lib = require("neogit.lib")
local signs = require("neogit.lib.signs")
local hl = require("neogit.lib.hl")
local status = require("neogit.status")
local state = require("neogit.lib.state")
local input = require("neogit.lib.input")
local logger = require("neogit.logger")

local cli = require("neogit.lib.git.cli")
local notification = require("neogit.lib.notification")

---@class OpenOpts
---@field cwd string|nil
---TODO: popup enum
---@field [1] string|nil
---@field kind string|nil
---@field no_expand boolean|nil

local did_setup = false

---Setup neogit
---@param opts NeogitConfig
local setup = function(opts)
  if did_setup then
    logger.debug("Already did setup!")
    return
  end
  did_setup = true

  config.setup(opts)
  hl.setup()
  signs.setup()
  state.setup()

  require("neogit.autocmds").setup()
end

---@param opts OpenOpts|nil
local open = function(opts)
  opts = opts or {}

  if opts.cwd and not opts.no_expand then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  if not opts.cwd then
    opts.cwd = vim.fn.getcwd()
  end

  if not did_setup then
    notification.create("Neogit has not been setup!", vim.log.levels.ERROR)
    logger.error("Neogit not setup!")
    return
  end

  if not cli.git_is_repository_sync(opts.cwd) then
    if
      input.get_confirmation(
        string.format("Initialize repository in %s?", opts.cwd or vim.fn.getcwd()),
        { values = { "&Yes", "&No" }, default = 2 }
      )
    then
      lib.git.init.create(opts.cwd or vim.fn.getcwd(), true)
    else
      notification.create("The current working directory is not a git repository", vim.log.levels.ERROR)
      return
    end
  end

  if opts[1] ~= nil then
    local popup_name = opts[1]
    local has_pop, popup = pcall(require, "neogit.popups." .. popup_name)

    if not has_pop then
      vim.api.nvim_err_writeln("Invalid popup '" .. popup_name .. "'")
    else
      popup.create {}
    end
  else
    a.run(function()
      if status.status_buffer then
        vim.cmd(string.format("cd %s", opts.cwd))
        status.refresh(true)
      else
        status.create(opts.kind, opts.cwd)
      end
    end)
  end
end

local complete = function(arglead)
  if arglead:find("^kind=") then
    return {
      "kind=replace",
      "kind=tab",
      "kind=split",
      "kind=split_above",
      "kind=vsplit",
      "kind=floating",
      "kind=auto",
    }
  end
  -- Only complete arguments that start with arglead
  return vim.tbl_filter(function(arg)
    return arg:match("^" .. arglead)
  end, { "kind=", "cwd=", "commit" })
end

return {
  lib = require("neogit.lib"),
  popups = require("neogit.popups"),
  config = config,
  status = status,
  get_repo = function()
    return require("neogit.lib.git").repo
  end,
  cli = lib.git.cli,
  get_log_file_path = function()
    return vim.fn.stdpath("cache") .. "/neogit.log"
  end,
  notif = require("neogit.lib.notification"),
  open = open,
  reset = status.reset,
  get_config = function()
    return config.values
  end,
  dispatch_reset = status.dispatch_reset,
  refresh = status.refresh,
  refresh_manually = status.refresh_manually,
  dispatch_refresh = status.dispatch_refresh,
  refresh_viml_compat = status.refresh_viml_compat,
  close = status.close,
  setup = setup,
  complete = complete,
  autocmd_group = vim.api.nvim_create_augroup("Neogit", { clear = false }),
}
