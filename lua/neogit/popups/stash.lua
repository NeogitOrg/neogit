local a = require('neogit.async')
local popup = require('neogit.lib.popup')
local stash = require('neogit.lib.git.stash')

local configuration = {
  {
    --{
      --key = "a",
      --description = "",
      --cli = "all",
      --enabled = false
    --},
    --{
      --key = "u",
      --description = "",
      --cli = "include-untracked",
      --enabled = false
    --}
  },
  {},
  {
    {
      {
        key = "z",
        description = "both",
        callback = function ()
          a.dispatch(function ()
            a.wait(stash.stash_all())
            __NeogitStatusRefresh(true)
          end)
        end
      },
      {
        key = "i",
        description = "index",
        callback = function ()
          a.dispatch(function ()
            a.wait(stash.stash_index())
            __NeogitStatusRefresh(true)
          end)
        end
      },
    }
  }
}
local function create()
  popup.create("NeogitStashPopup", unpack(configuration))
end

return {
  create = create
}
