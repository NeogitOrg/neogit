local cli = require("neogit.lib.git.cli")
local notification = require("neogit.lib.notification")
local input = require("neogit.lib.input")

local M = {}

M.create = function(directory, sync)
  sync = sync or false

  if sync then
    cli.init.args(directory).call_sync()
  else
    cli.init.args(directory).call()
  end
end

M.init_repo = function()
  local directory = vim.fn.input {
    prompt = "Create repository in: ",
    text = "",
    cancelreturn = "",
    completion = "dir",
  }
  if directory == "" then
    return
  end

  -- git init doesn't understand ~
  directory = vim.fn.fnamemodify(directory, ":p")

  if vim.fn.isdirectory(directory) == 0 then
    notification.error("You entered an invalid directory")
    return
  end

  if cli.git_is_repository_sync() then
    if
      not input.get_confirmation(
        string.format("Reinitialize existing repository %s?", directory),
        { values = { "&Yes", "&No" }, default = 2 }
      )
    then
      return
    end
  end

  local status = require("neogit.status")
  status.cwd_changed = true
  vim.cmd.lcd(directory)

  M.create(directory)

  status.refresh(true, "InitRepo")
end

return M
