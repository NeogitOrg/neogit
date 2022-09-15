local RPC = require("neogit.lib.rpc")
local fn = vim.fn
local fmt = string.format

local M = {}

function M.get_nvim_remote_editor()
  local neogit_path = debug.getinfo(1, "S").source:sub(2, -#"lua/neogit/client.lua" - 2)
  local nvim_path = vim.v.progpath

  local runtimepath_cmd = fn.shellescape(fmt("set runtimepath^=%s", fn.fnameescape(tostring(neogit_path))))
  local lua_cmd = fn.shellescape('lua require("neogit.client").client()')

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

  local client = fn.serverstart()
  local lua_cmd = fmt('lua require("neogit.client").editor("%s", "%s")', file_target, client)

  local rpc_server = RPC.create_connection(nvim_server)
  rpc_server:send_cmd(lua_cmd)
end

--- Invoked by the `client` and starts the appropriate file editor
function M.editor(target, client)
  local editor = require("neogit.editor")

  local rpc_client = RPC.create_connection(client)
  local function send_client_quit()
    rpc_client:send_cmd_async("qall")
    rpc_client:disconnect()
  end

  if target:find("git%-rebase%-todo$") then
    editor.rebase_editor(target, send_client_quit)
  elseif target:find("COMMIT_EDITMSG$") then
    editor.commit_editor(target, send_client_quit)
  else
    local notif = require("neogit.lib.notification")
    notif.create(target .. " has not been implemented yet", vim.log.levels.WARN)
    send_client_quit()
  end
end

return M
