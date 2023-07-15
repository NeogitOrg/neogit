local M = {}

---@param name string
--@param get_args nil|fun(): any
--- Creates a curried function which will open the popup with the given name when called
--- Extra arguments are supplied to popup.`create()`
function M.open(name, get_args)
  return function()
    local ok, value = pcall(require, "neogit.popups." .. name)
    if ok then
      assert(value)
      local args = {}

      if get_args then
        args = { get_args() }
      end

      value.create(table.unpack(args))
    else
      local notification = require("neogit.lib.notification")
      notification.create(string.format("No such popup: %q", name), vim.log.levels.ERROR)
    end
  end
end

function M.test()
  M.open("echo", function()
    return "a", "b"
  end)()
end

return M
