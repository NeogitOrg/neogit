local uv = vim.loop
local util = require('neogit.lib.util')
local a = require('neogit.async')

local wrapper = setmetatable({}, {
  __index = function (tbl, action)
    if uv[action] then
      return a.wrap(uv[action])
    end

    return nil
  end
})

wrapper.read_file = a.sync(function (file)
  local err, fd = a.wait(wrapper.fs_open(file, 'r', 438))
  if err then return nil end
  local _, stat = a.wait(wrapper.fs_fstat(fd))
  local _, data = a.wait(wrapper.fs_read(fd, stat.size, 0))
  a.wait(wrapper.fs_close(fd))
  return data
end)

wrapper.read_lines = a.sync(function (file)
  local data = a.wait(wrapper.read_file(file))

  if data == nil then
    return nil
  end

  -- we need \r? to support windows
  data = util.split(data, '\r?\n')
  return data
end)

return wrapper
