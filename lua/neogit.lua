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

  if vim.fn.has("nvim-0.10") == 1 then
    M.notification.info("The 'nightly' branch for Neogit provides support for nvim-0.10")
  end
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
    opts.cwd = require("neogit.lib.git.cli").git_root_of_cwd()
  end

  if not did_setup then
    notification.error("Neogit has not been setup!")
    logger.error("Neogit not setup!")
    return
  end

  if not cli.is_inside_worktree(opts.cwd) then
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
        status.refresh(nil, "open")
      else
        status.create(opts.kind, opts.cwd)
      end
    end)
  end
end

-- This can be used to create bindable functions for custom keybindings:
--   local neogit = require("neogit")
--   vim.keymap.set('n', '<leader>gcc', neogit.action('commit', 'commit', { '--verbose', '--all' }))
--
---@param popup  string Name of popup, as found in `lua/neogit/popups/*`
---@param action string Name of action for popup, found in `lua/neogit/popups/*/actions.lua`
---@param args   table? CLI arguments to pass to git command
---@return function
function M.action(popup, action, args)
  local notification = require("neogit.lib.notification")
  local util = require("neogit.lib.util")
  local a = require("plenary.async")

  args = args or {}

  local internal_args = {
    graph = util.remove_item_from_table(args, "--graph"),
    color = util.remove_item_from_table(args, "--color"),
    decorate = util.remove_item_from_table(args, "--decorate"),
  }

  return function()
    a.run(function()
      local ok, actions = pcall(require, "neogit.popups." .. popup .. ".actions")
      if ok then
        local fn = actions[action]
        if fn then
          fn {
            state = { env = {} },
            get_arguments = function()
              return args
            end,
            get_internal_arguments = function()
              return internal_args
            end,
          }
        else
          notification.error(
            string.format(
              "Invalid action %s for %s popup\nValid actions are: %s",
              action,
              popup,
              table.concat(vim.tbl_keys(actions), ", ")
            )
          )
        end
      else
        notification.error("Invalid popup: " .. popup)
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

function M.get_log_file_path()
  return vim.fn.stdpath("cache") .. "/neogit.log"
end

function M.get_config()
  return require("neogit.config").values
end

return M
