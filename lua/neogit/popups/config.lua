local M = {}

local Buffer = require 'neogit.lib.buffer'
local cli = require 'neogit.lib.git.cli'
local input = require 'neogit.lib.input'
local ui = require 'neogit.lib.ui'
local util = require 'neogit.lib.util'
local common = require 'neogit.buffers.common'
local uv = require 'neogit.lib.uv'

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
      description = "set value",
      callback = function(buffer, this)
        local c = buffer.ui:get_component_under_cursor(function(c)
          return c.options.tag == "Option"
        end)
        if c then
          local option = this.find_value(c.options.id) 
          -- if the value changed
          if this.set_value(option) then
            local txt = c.children[3]
            txt.value = option.value
            txt.options.highlight = this.value_type_to_highlight[option.type]
            buffer.ui:update()
          end
        end
      end
    }
  },
  {
    {
      key = "<c-s>l",
      description = "save config to local location",
      callback = function(buffer, this)
        if input.get_confirmation("This will replace the local config. Are you sure?") then
          local output = {}
          for _, value in ipairs(this.values) do 
            table.insert(output, string.format("%s=%s", value.id, value.value))
          end
          uv.write_file_sync("", output)
          buffer:close()
        end
      end
    },
    {
      key = "<c-s>g",
      description = "save config to global location"
    },
    {
      key = "<c-s>s",
      description = "save config to system location"
    },
  }
}

local function get_type_of_value(value)
  if value == "true" or value == "false" then
    return "boolean"
  elseif tonumber(value) then
    return "number"
  else
    return "string"
  end
end

function M.create()
  local values = map(cli.config.list.call_sync(), function(raw)
    local data = {}

    data.id, data.value = raw:match("(.*)=(.*)")
    data.type = get_type_of_value(data.value)

    return data
  end)

  local function find_value(id)
    for _, x in ipairs(values) do
      if x.id == id then
        return x
      end
    end
  end

  local function set_value(option)
    local prev_value = option.value
    option.value = input.get_user_input(option.id .. " = ", {
      default_value = option.value,
      cancel_value = option.value
    })
    local changed = prev_value ~= option.value

    if changed then
      option.type = get_type_of_value(option.value)
    end

    return changed
  end

  local value_type_to_highlight = {
    string = "String",
    boolean = "Boolean",
    number = "Number"
  }

  local nmappings = {}
  local this = {
    values = values,
    find_value = find_value,
    set_value = set_value,
    value_type_to_highlight = value_type_to_highlight
  }

  for _, x in ipairs(actions) do
    for _, a in ipairs(x) do
      nmappings[a.key] = a.callback 
        and function(buffer)
          a.callback(buffer, this)
        end or function()
          local notif = require 'neogit.lib.notification'
          notif.create("TODO: not implemented yet", {
            type = "error"
          })
        end
    end
  end

  Buffer.create {
    name = "NeogitConfigPopup",
    filetype = "NeogitPopup",
    kind = "split",
    mappings = {
      n = nmappings
    },
    render = function()
      return {
        List {
          separator = "",
          items = {
            col {
              text.highlight("NeogitPopupSectionTitle") "Values",
              col.padding_left(1)(map(values, function(v)
                return row.tag("Option").id(v.id) { 
                  text.highlight("NeogitPopupActionKey")(v.id), 
                  text " = ", 
                  text.highlight(value_type_to_highlight[v.type])(v.value) 
                }
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
