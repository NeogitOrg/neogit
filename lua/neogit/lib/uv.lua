local a = require 'plenary.async_lib'
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

M.read_file_sync = function(path)
  local output = {}

  for line in io.lines(path) do
    table.insert(output, line)
  end

  return output
end

M.write_file_sync = function(path, content)
  local file = io.open(path, "w")
  file:write(table.concat(content, "\n"))
  file:close()
end

return M
