local fn = vim.fn

local RPC = {}

-- @class RPC
-- @field address
-- @field ch
--
--- Creates a new rpc channel
-- @param address
-- @return RPC
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
  self.ch = fn.sockconnect("pipe", self.address, { rpc = true })
end

function RPC:disconnect()
  fn.chanclose(self.ch)
  self.ch = nil
end

function RPC:send_cmd(cmd)
  vim.rpcrequest(self.ch, "nvim_command", cmd)
end

function RPC:send_cmd_async(cmd)
  vim.rpcnotify(self.ch, "nvim_command", cmd)
end

return RPC
