local a = require 'plenary.async_lib'
local util = require 'neogit.lib.util'
local async, await, uv = a.async, a.await, a.uv

local M = {}

M.read_file = async(function(path)
  local err, fd = await(uv.fs_open(path, "r", 438))
  if err then return err end

  local err, stat = await(uv.fs_fstat(fd))
  if err then return err end

  local err, data = await(uv.fs_read(fd, stat.size, 0))
  if err then return err end

  local err = await(uv.fs_close(fd))
  if err then return err end

  return nil, data
end)

M.read_lines = async(function (file)
  local err, data = await(M.read_file(file))
  
  if err then return err end

  if data == nil then
    return nil
  end

  -- we need \r? to support windows
  data = util.split(data, '\r?\n')
  return nil, data
end)

return M
