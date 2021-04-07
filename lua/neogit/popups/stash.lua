local a = require 'plenary.async_lib'
local async, await, void = a.async, a.await, a.void
local status = require 'neogit.status'
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
        callback = void(async(function ()
          await(stash.stash_all())
          status.refresh(true)
        end))
      },
      {
        key = "i",
        description = "index",
        callback = void(async(function ()
          await(stash.stash_index())
          status.refresh(true)
        end))
      },
    },
    {
      {
        key = "p",
        description = "pop",
        callback = function (popup)
          local line = vim.fn.getbufline(popup.env.pos[1], popup.env.pos[2])
          local stash_name = line[1]:match('^(stash@{%d+})')
          if stash_name then
            a.scope(function ()
              await(stash.pop(stash_name))
              status.refresh(true)
            end)
          end
        end
      },
      {
        key = "a",
        description = "apply",
        callback = function (popup)
          local line = vim.fn.getbufline(popup.env.pos[1], popup.env.pos[2])
          local stash_name = line[1]:match('^(stash@{%d+})')
          if stash_name then
            a.scope(function ()
              await(stash.apply(stash_name))
              status.refresh(true)
            end)
          end
        end
      },
      {
        key = "d",
        description = "drop",
        callback = function (popup)
          local line = vim.fn.getbufline(popup.env.pos[1], popup.env.pos[2])
          local stash_name = line[1]:match('^(stash@{%d+})')
          if stash_name then
            a.scope(function ()
              await(stash.drop(stash_name))
              status.refresh(true)
            end)
          end
        end
      }
    }
  }
}
local function create(pos)
  popup.create("NeogitStashPopup", configuration[1], configuration[2], configuration[3], {
    pos = pos
  })
end

return {
  create = create
}
