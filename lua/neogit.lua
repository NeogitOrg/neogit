local config = require("neogit.config")
local a = require("plenary.async")
local lib = require("neogit.lib")
local signs = require("neogit.lib.signs")
local hl = require("neogit.lib.hl")
local status = require("neogit.status")
local state = require("neogit.lib.state")
local input = require("neogit.lib.input")

local cli = require("neogit.lib.git.cli")
local notification = require("neogit.lib.notification")

local function notify_move()
  local async = require("plenary.async")
  async.run(function()
    local Path = require("plenary.path")
    local path = debug.getinfo(1, "S").source:sub(2)
    local path = Path:new(path):parent():parent():absolute()

    local git = require("neogit.lib.git")

    local url = git.cli.config.get("remote.origin.url").cwd(path).show_popup(false).call():trim().stdout
    local url = url and url[1]

    if url then
      url = string.lower(url)
    end

    -- Warn on misconfigured remotes as well
    if url and string.match(url, "timuntersberger/neogit") then
      vim.defer_fn(function()
        notification.create(
          [[Neogit has moved to an organization at <https://github.com/NeogitOrg/neogit/issues> to ensure the longevity of this project and ensure that it is more accessible to collaborators.

Please update your plugin configuration or remote :)
          ]],
          vim.log.levels.WARN,
          5000
        )
      end, 1000)
    end
  end)
end

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

    if not cli.git_is_repository_sync(opts.cwd) then
      if
        input.get_confirmation(
          string.format("Create repository in %s? (y or n)", opts.cwd or vim.fn.getcwd()),
          {
            default = 2,
          }
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
        popup.create()
      end
    else
      a.run(function()
        status.create(opts.kind, opts.cwd)
      end)
    end
  end,
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
  setup = function(opts)
    notify_move()
    if opts ~= nil then
      config.values = vim.tbl_deep_extend("force", config.values, opts)
    end
    if not config.values.disable_signs then
      signs.setup()
    end
    if config.values.use_magit_keybindings then
      config.values.mappings.status["F"] = "PullPopup"
      config.values.mappings.status["p"] = ""
    end
    hl.setup()
    state.setup()

    require("neogit.autocmds").setup()
  end,
  complete = function(arglead)
    if arglead:find("^kind=") then
      return { "kind=replace", "kind=tab", "kind=split", "kind=split_above", "kind=vsplit", "kind=floating" }
    end
    -- Only complete arguments that start with arglead
    return vim.tbl_filter(function(arg)
      return arg:match("^" .. arglead)
    end, { "kind=", "cwd=", "commit" })
  end,
}

neogit.setup()

return neogit
