local M = {}

local Buffer = require 'neogit.lib.buffer'
local ui = require 'neogit.lib.ui'
local util = require 'neogit.lib.util'
local common = require 'neogit.buffers.common'

local List = common.List
local Grid = common.Grid
local text = ui.text
local row = ui.row
local col = ui.col
local map = util.map

local actions = {
  {
    {
      key = "s",
      description = "set value"
    }
  }
}

function M.create()
  local values = {
    {
      id = "commit.template",
      value = "~/.gitmessage"
    }
  }
  Buffer.create {
    name = "NeogitConfigPopup",
    filetype = "NeogitPopup",
    kind = "split",
    mappings = {},
    render = function()
      return {
        List {
          separator = "",
          items = {
            col {
              text.highlight("NeogitPopupSectionTitle") "Values",
              col.padding_left(1)(map(values, function(v)
                return row { text.highlight("NeogitPopupActionKey")(v.id), text " = ", text(v.value) }
              end))
            },
            col {
              text.highlight("NeogitPopupSectionTitle") "Actions",
              Grid.padding_left(1) {
                items = actions,
                gap = 1,
                render_item = function(item)
                  return row {
                    text.highlight("NeogitPopupActionKey")(item.key),
                    text " ",
                    text(item.description),
                  }
                end
              }
            }
          }
        }
      }
    end
  }
end

return M
