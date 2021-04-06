local uv = vim.loop
local a = require('plenary.async_lib')
local async, await = a.async, a.await

local wrapper = setmetatable({}, {
  __index = function (tbl, action)
    if uv[action] then
      return a.wrap(uv[action])
    end

    return nil
  end
})

wrapper.read_file = async(function (file)
  local err, fd = await(wrapper.fs_open(file, 'r', 438))
  if err then return nil end
  local _, stat = await(wrapper.fs_fstat(fd))
  local _, data = await(wrapper.fs_read(fd, stat.size, 0))
  await(wrapper.fs_close(fd))
  return data
end)

return wrapper
