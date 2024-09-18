---@class RPC
---@field address string
---@field channel_id integer
---@field mode string Assume TPC if the address ends with a port like '...:XXXX'
---| 'tcp'
---| 'pipe'
local RPC = {}

---Creates a new rpc channel
---@param address string
---@return RPC
function RPC.new(address)
  local instance = {
    address = address,
    channel_id = nil,
    mode = address:match(":%d+$") and "tcp" or "pipe",
  }

  setmetatable(instance, { __index = RPC })

  return instance
end

function RPC.create_connection(address)
  local rpc = RPC.new(address)
  rpc:connect()

  return rpc
end

function RPC:connect()
  self.channel_id = vim.fn.sockconnect(self.mode, self.address, { rpc = true })
end

function RPC:disconnect()
  vim.fn.chanclose(self.channel_id)
  self.channel_id = nil
end

function RPC:send_cmd(cmd)
  vim.rpcrequest(self.channel_id, "nvim_command", cmd)
end

function RPC:send_cmd_async(cmd)
  vim.rpcnotify(self.channel_id, "nvim_command", cmd)
end

return RPC
