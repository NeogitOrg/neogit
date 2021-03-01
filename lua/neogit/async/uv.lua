local uv = vim.loop
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

return wrapper
