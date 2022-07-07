local RPC = require("neogit.lib.rpc")
local fn = vim.fn
local fmt = string.format

local M = {}

function M.client()
  local nvim_server = vim.env.NVIM

  local file_target = fn.fnamemodify(fn.argv()[1], ":p")

  local client = fn.serverstart()
  local lua_cmd = fmt('lua require("neogit.client").editor("%s", "%s")', file_target, client)

  local rpc_server = RPC.create_connection(nvim_server)
  rpc_server:send_cmd(lua_cmd)
end

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
    send_client_quit()
  end
end

return M
