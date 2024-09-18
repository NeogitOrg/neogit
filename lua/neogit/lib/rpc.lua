---@class RPC
---@field address string
---@field ch string
local RPC = {}

---Creates a new rpc channel
---@param address string
---@return RPC
function RPC.new(address)
  local instance = {
    address = address,
    ch = nil,
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
  -- assume TPC if the address ends with :<some numbers>
  local mode = self.address:match(":%d+$") and "tcp" or "pipe"
  self.ch = vim.fn.sockconnect(mode, self.address, { rpc = true })
end

function RPC:disconnect()
  vim.fn.chanclose(self.ch)
  self.ch = nil
end

function RPC:send_cmd(cmd)
  vim.rpcrequest(self.ch, "nvim_command", cmd)
end

function RPC:send_cmd_async(cmd)
  vim.rpcnotify(self.ch, "nvim_command", cmd)
end

return RPC
