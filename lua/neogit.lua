local M = {}

local did_setup = false

---Setup neogit
---@param opts NeogitConfig
function M.setup(opts)
  local config = require("neogit.config")
  local signs = require("neogit.lib.signs")
  local autocmds = require("neogit.autocmds")
  local hl = require("neogit.lib.hl")
  local state = require("neogit.lib.state")
  local logger = require("neogit.logger")

  if did_setup then
    logger.debug("Already did setup!")
    return
  end
  did_setup = true

  M.autocmd_group = vim.api.nvim_create_augroup("Neogit", { clear = false })

  M.status = require("neogit.status")
  M.dispatch_reset = M.status.dispatch_reset
  M.refresh = M.status.refresh
  M.reset = M.status.reset
  M.refresh_manually = M.status.refresh_manually
  M.dispatch_refresh = M.status.dispatch_refresh
  M.refresh_viml_compat = M.status.refresh_viml_compat
  M.close = M.status.close

  M.lib = require("neogit.lib")
  M.cli = M.lib.git.cli
  M.popups = require("neogit.popups")
  M.config = config
  M.notification = require("neogit.lib.notification")

  config.setup(opts)
  hl.setup()
  signs.setup()
  state.setup()
  autocmds.setup()
end

---@alias Popup "cherry_pick" | "commit" | "branch" | "diff" | "fetch" | "log" | "merge" | "remote" | "pull" | "push" | "rebase" | "revert" | "reset" | "stash"
---
---@class OpenOpts
---@field cwd string|nil
---@field [1] Popup|nil
---@field kind string|nil
---@field no_expand boolean|nil

---@param opts OpenOpts|nil
function M.open(opts)
  local a = require("plenary.async")
  local lib = require("neogit.lib")
  local status = require("neogit.status")
  local input = require("neogit.lib.input")
  local cli = require("neogit.lib.git.cli")
  local logger = require("neogit.logger")
  local notification = require("neogit.lib.notification")

  opts = opts or {}

  if opts.cwd and not opts.no_expand then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  if not opts.cwd then
    opts.cwd = vim.fn.getcwd()
  end

  if not did_setup then
    notification.error("Neogit has not been setup!")
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
      notification.error("The current working directory is not a git repository")
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
        vim.cmd.lcd(opts.cwd)
        status.refresh(true)
      else
        status.create(opts.kind, opts.cwd)
      end
    end)
  end
end

function M.complete(arglead)
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

function M.get_repo()
  return require("neogit.lib.git").repo
end

function M.get_log_file_path()
  return vim.fn.stdpath("cache") .. "/neogit.log"
end

function M.get_config()
  return require("neogit.config").values
end

return M
