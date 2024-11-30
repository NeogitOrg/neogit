local M = {}

local did_setup = false

---Setup neogit
---@param opts NeogitConfig
function M.setup(opts)
  if vim.fn.has("nvim-0.10") ~= 1 then
    vim.notify("Neogit HEAD requires at least NVIM 0.10 - Pin to tag 'v0.0.1' for NVIM 0.9.x")
    return
  end

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

  M.status = require("neogit.buffers.status")

  M.dispatch_reset = function()
    local instance = M.status.instance()
    if instance then
      instance:dispatch_reset()
    end
  end

  M.refresh = function()
    local instance = M.status.instance()
    if instance then
      instance:refresh()
    end
  end

  M.reset = function()
    local instance = M.status.instance()
    if instance then
      instance:reset()
    end
  end

  M.dispatch_refresh = function()
    local instance = M.status.instance()
    if instance then
      instance:dispatch_refresh()
    end
  end

  M.close = function()
    local instance = M.status.instance()
    if instance then
      instance:close()
    end
  end

  M.lib = require("neogit.lib")
  M.cli = M.lib.git.cli
  M.popups = require("neogit.popups")
  M.config = config
  M.notification = require("neogit.lib.notification")

  config.setup(opts)
  hl.setup(config.values)
  signs.setup(config.values)
  state.setup(config.values)
  autocmds.setup()
end

local function construct_opts(opts)
  opts = opts or {}

  if opts.cwd and not opts.no_expand then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  if not opts.cwd then
    local git = require("neogit.lib.git")
    opts.cwd = git.cli.worktree_root(".")

    if opts.cwd == "" then
      opts.cwd = vim.uv.cwd()
    end
  end

  return opts
end

local function open_popup(name)
  local has_pop, popup = pcall(require, "neogit.popups." .. name)
  if not has_pop then
    M.notification.error(("Invalid popup %q"):format(name))
  else
    popup.create {}
  end
end

local function open_status_buffer(opts)
  local status = require("neogit.buffers.status")
  local config = require("neogit.config")

  -- We need to construct the repo instance manually here since the actual CWD may not be the directory neogit is
  -- going to open into. We will use vim.fn.lcd() in the status buffer constructor, so this will eventually be
  -- correct.
  local repo = require("neogit.lib.git.repository").instance(opts.cwd)
  status.new(config.values, repo.worktree_root, opts.cwd):open(opts.kind):dispatch_refresh()
end

---@alias Popup
---| "bisect"
---| "branch"
---| "branch_config"
---| "cherry_pick"
---| "commit"
---| "diff"
---| "fetch"
---| "help"
---| "ignore"
---| "log"
---| "merge"
---| "pull"
---| "push"
---| "rebase"
---| "remote"
---| "remote_config"
---| "reset"
---| "revert"
---| "stash"
---| "tag"
---| "worktree"

---@class OpenOpts
---@field cwd string|nil
---@field [1] Popup|nil
---@field kind string|nil
---@field no_expand boolean|nil

---@param opts OpenOpts|nil
function M.open(opts)
  if not did_setup then
    M.setup {}
  end

  opts = construct_opts(opts)

  local git = require("neogit.lib.git")
  if not git.cli.is_inside_worktree(opts.cwd) then
    local input = require("neogit.lib.input")
    if input.get_permission(("Initialize repository in %s?"):format(opts.cwd)) then
      git.init.create(opts.cwd)
    else
      M.notification.error("The current working directory is not a git repository")
      return
    end
  end

  if opts[1] ~= nil then
    local a = require("plenary.async")
    local cb = function()
      open_popup(opts[1])
    end

    a.void(function()
      git.repo:dispatch_refresh { source = "popup", callback = cb }
    end)()
  else
    open_status_buffer(opts)
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
  local util = require("neogit.lib.util")
  local a = require("plenary.async")

  args = args or {}

  local internal_args = {
    graph = util.remove_item_from_table(args, "--graph"),
    color = util.remove_item_from_table(args, "--color"),
    decorate = util.remove_item_from_table(args, "--decorate"),
  }

  return function()
    a.void(function()
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
          M.notification.error(
            string.format(
              "Invalid action %s for %s popup\nValid actions are: %s",
              action,
              popup,
              table.concat(vim.tbl_keys(actions), ", ")
            )
          )
        end
      else
        M.notification.error("Invalid popup: " .. popup)
      end
    end)()
  end
end

function M.complete(arglead)
  if arglead:find("^kind=") then
    return {
      "kind=replace",
      "kind=tab",
      "kind=split",
      "kind=split_above",
      "kind=split_above_all",
      "kind=split_below",
      "kind=split_below_all",
      "kind=vsplit",
      "kind=floating",
      "kind=auto",
    }
  end

  if arglead:find("^cwd=") then
    return {
      "cwd=" .. vim.uv.cwd(),
    }
  end

  return vim.tbl_filter(function(arg)
    return arg:match("^" .. arglead)
  end, {
    "kind=",
    "cwd=",
    "bisect",
    "branch",
    "branch_config",
    "cherry_pick",
    "commit",
    "diff",
    "fetch",
    "help",
    "ignore",
    "log",
    "merge",
    "pull",
    "push",
    "rebase",
    "remote",
    "remote_config",
    "reset",
    "revert",
    "stash",
    "tag",
    "worktree",
  })
end

function M.get_log_file_path()
  return vim.fn.stdpath("cache") .. "/neogit.log"
end

function M.get_config()
  return M.config.values
end

return M
