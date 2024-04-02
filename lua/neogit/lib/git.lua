local Git = {
  __index = function(_, k)
    if k == "repo" then
      return require("neogit.lib.git.repository").instance()
    else
      return require("neogit.lib.git." .. k)
    end
  end,
}

return setmetatable({}, Git)
