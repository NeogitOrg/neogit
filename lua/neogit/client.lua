local RPC = require("neogit.lib.rpc")
local logger = require("neogit.logger")
local config = require("neogit.config")

local fn = vim.fn
local fmt = string.format

local M = {}

function M.get_nvim_remote_editor()
  local neogit_path = debug.getinfo(1, "S").source:sub(2, -#"lua/neogit/client.lua" - 2)
  local nvim_path = fn.shellescape(vim.v.progpath)

  logger.debug("[CLIENT] Neogit path: " .. neogit_path)
  logger.debug("[CLIENT] Neovim path: " .. nvim_path)
  local runtimepath_cmd = fn.shellescape(fmt("set runtimepath^=%s", fn.fnameescape(tostring(neogit_path))))
  local lua_cmd = fn.shellescape("lua require('neogit.client').client()")

  local shell_cmd = {
    nvim_path,
    "--headless",
    "--clean",
    "--noplugin",
    "-n",
    "-R",
    "-c",
    runtimepath_cmd,
    "-c",
    lua_cmd,
  }

  return table.concat(shell_cmd, " ")
end

function M.get_envs_git_editor()
  local nvim_cmd = M.get_nvim_remote_editor()
  return {
    GIT_SEQUENCE_EDITOR = nvim_cmd,
    GIT_EDITOR = nvim_cmd,
  }
end

--- Entry point for the headless client.
--- Starts a server and connects to the parent process rpc, opening an editor
function M.client()
  local nvim_server = vim.env.NVIM
  if not nvim_server then
    error("NVIM server address not set")
  end

  local file_target = fn.fnamemodify(fn.argv()[1], ":p")
  logger.fmt_debug("[CLIENT] File target: %s", file_target)

  local client = fn.serverstart()
  logger.fmt_debug("[CLIENT] Client address: %s", client)

  local lua_cmd = fmt('lua require("neogit.client").editor("%s", "%s")', file_target, client)

  if vim.loop.os_uname().sysname == "Windows_NT" then
    lua_cmd = lua_cmd:gsub("\\", "/")
  end

  local rpc_server = RPC.create_connection(nvim_server)
  rpc_server:send_cmd(lua_cmd)
end

--- Invoked by the `client` and starts the appropriate file editor
---@param target string Filename to open
---@param client string Address returned from vim.fn.serverstart()
function M.editor(target, client)
  logger.fmt_debug("[CLIENT] Invoked editor with target: %s, from: %s", target, client)
  require("neogit.process").hide_preview_buffers()

  local rpc_client = RPC.create_connection(client)

  ---on_unload callback when closing editor
  ---@param status integer Status code to close remote nvim instance with. 0 for success, 1 for failure
  local function send_client_quit(status)
    if status == 0 then
      rpc_client:send_cmd_async("qall")
    elseif status == 1 then
      rpc_client:send_cmd_async("cq")
    end

    rpc_client:disconnect()
  end

  local kind
  if target:find("COMMIT_EDITMSG$") then
    kind = config.values.commit_editor.kind
  elseif target:find("MERGE_MSG$") then
    kind = config.values.merge_editor.kind
  elseif target:find("TAG_EDITMSG$") then
    kind = config.values.tag_editor.kind
  elseif target:find("EDIT_DESCRIPTION$") then
    kind = config.values.description_editor.kind
  elseif target:find("git%-rebase%-todo$") then
    kind = config.values.rebase_editor.kind
  else
    kind = "auto"
  end

  local editor
  if target:find("git%-rebase%-todo$") then
    editor = require("neogit.buffers.rebase_editor")
  else
    editor = require("neogit.buffers.editor")
  end

  editor.new(target, send_client_quit):open(kind)
end

---@class NotifyMsg
---@field setup string|nil Message to show before running
---@field success string|nil Message to show when successful
---@field fail string|nil Message to show when failed

---@class WrapOpts
---@field autocmd string
---@field msg NotifyMsg

---@param cmd any
---@param opts WrapOpts
---@return integer code of `cmd`
function M.wrap(cmd, opts)
  local notification = require("neogit.lib.notification")
  local a = require("plenary.async")

  a.util.scheduler()

  if opts.msg.setup then
    notification.info(opts.msg.setup)
  end
  local result = cmd.env(M.get_envs_git_editor()):in_pty(true).call { verbose = true }

  a.util.scheduler()

  if result.code == 0 then
    if opts.msg.success then
      notification.info(opts.msg.success, { dismiss = true })
    end
    vim.api.nvim_exec_autocmds("User", { pattern = opts.autocmd, modeline = false })
  else
    if opts.msg.fail then
      notification.warn(opts.msg.fail, { dismiss = true })
    end
  end
  return result.code
end

return M
