local a = require 'plenary.async'

local M = {}

function M.read_file(path)
  local err, fd = a.uv.fs_open(path, "r", 438)
  if err then return err end

  local err, stat = a.uv.fs_fstat(fd)
  if err then return err end

  local err, data = a.uv.fs_read(fd, stat.size, 0)
  if err then return err end

  local err = a.uv.fs_close(fd)
  if err then return err end

  return nil, data
end

M.read_file_sync = function(path)
  local output = {}

  for line in io.lines(path) do
    table.insert(output, line)
  end

  return output
end

return M
