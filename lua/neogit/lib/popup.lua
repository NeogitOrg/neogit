local PopupBuilder = require 'neogit.lib.popup.builder'
local Buffer = require 'neogit.lib.buffer'
local common = require 'neogit.buffers.common'
local Ui = require 'neogit.lib.ui'
local logger = require 'neogit.logger'
local util = require 'neogit.lib.util'

local col = Ui.col
local row = Ui.row
local text = Ui.text
local Component = Ui.Component
local map = util.map
local List = common.List
local Grid = common.Grid

local M = {}

function M.builder()
  return PopupBuilder.new(M.new)
end

function M.new(state)
  local instance = {
    state = state,
    buffer = nil
  }
  setmetatable(instance, { __index = M })
  return instance
end

function M:get_arguments()
  local flags = {}
  for _, switch in pairs(self.state.switches) do
    if switch.enabled and switch.parse ~= false then
      table.insert(flags, "--" .. switch.cli)
    end
  end
  for _, option in pairs(self.state.options) do
    if #option.value ~= 0 and option.parse ~= false then
      table.insert(flags, "--" .. option.cli .. "=" .. option.value)
    end
  end
  return flags
end

function M:get_parse_arguments()
  local switches = {}
  for _, switch in pairs(self.state.switches) do
    if switch.enabled and switch.parse then
      switches[switch.cli] = switch.enabled
    end
  end
  return switches
end

function M:to_cli()
  return table.concat(self:get_arguments(), " ")
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end

local function get_highlight_for_switch(switch)
  if switch.enabled then
    return "NeogitPopupSwitchEnabled"
  end

  return "NeogitPopupSwitchDisabled"
end

local function get_highlight_for_option(option)
  if option.value ~= nil and option.value ~= "" then
    return "NeogitPopupOptionEnabled"
  end

  return "NeogitPopupOptionDisabled"
end

function M:toggle_switch(switch)
  switch.enabled = not switch.enabled
  local c = self.buffer.ui:find_component(function(c)
    return c.options.id == switch.id
  end)
  c.options.highlight = get_highlight_for_switch(switch)
  self.buffer.ui:update()
end

function M:set_option(option)
  option.value = vim.fn.input({
    prompt = option.cli .. "=",
    default = option.value,
    cancelreturn = option.value
  })
  local c = self.buffer.ui:find_component(function(c)
    return c.options.id == option.id
  end)
  c.options.highlight = get_highlight_for_option(option)
  c.children[#c.children].value = option.value
  self.buffer.ui:update()
end

local Switches = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle") "Switches",
    col(map(props.state, function(switch)
      return row.tag("Switch").value(switch) {
        row.highlight("NeogitPopupSwitchKey") {
          text " -",
          text(switch.key),
        },
        text " ",
        text(switch.description),
        text " (",
        row.id(switch.id).highlight(get_highlight_for_switch(switch)) {
          text "--",
          text(switch.cli)
        },
        text ")"
      }
    end))
  }
end)

local Options = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle") "Options",
    col(map(props.state, function(option)
      return row.tag("Option").value(option) {
        row.highlight("NeogitPopupOptionKey") {
          text " =",
          text(option.key),
        },
        text " ",
        text(option.description),
        text " (",
        row.id(option.id).highlight(get_highlight_for_option(option)) {
          text "--",
          text(option.cli),
          text "=",
          text(option.value or "")
        },
        text ")"
      }
    end))
  }
end)

local Actions = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle") "Actions",
    Grid.padding_left(1) {
      items = props.state,
      gap = 1,
      render_item = function(item)
        if not item.callback then
          return row.highlight("NeogitPopupActionDisabled") {
            text(item.key),
            text " ",
            text(item.description),
          }
        end

        return row {
          text.highlight("NeogitPopupActionKey")(item.key),
          text " ",
          text(item.description),
        }
      end
    }
  }
end)

function M:show()
  local mappings = {
    n = {
      ["q"] = function()
        self:close()
      end,
      ["<tab>"] = function()
        local stack = self.buffer.ui:get_component_stack_under_cursor()

        for _,x in ipairs(stack) do
          if x.options.tag == "Switch" then
            self:toggle_switch(x.options.value)
            break
          elseif x.options.tag == "Option" then
            self:set_option(x.options.value)
            break
          end
        end
      end,
    }
  }

  for _, switch in pairs(self.state.switches) do
    mappings.n[switch.id] = function()
      self:toggle_switch(switch)
    end
  end

  for _, option in pairs(self.state.options) do
    mappings.n[option.id] = function()
      self:set_option(option)
    end
  end

  for _, group in pairs(self.state.actions) do
    for _, action in pairs(group) do
      if action.callback then
        mappings.n[action.key] = function()
          logger.debug(string.format("[POPUP]: Invoking action '%s' of %s", action.key, self.state.name))
          local ret = action.callback(self)
          self:close()
          if type(ret) == "function" then
            ret()
          end
        end
      else
        mappings.n[action.key] = function()
          local notif = require 'neogit.lib.notification'
          notif.create(action.description .. " has not been implemented yet", vim.log.levels.WARN)
        end
      end
    end
  end

  self.buffer = Buffer.create {
    name = self.state.name,
    filetype = "NeogitPopup",
    kind = "split",
    mappings = mappings,
    render = function()
      return {
        List {
          separator = "",
          items = {
            Switches { state = self.state.switches },
            Options { state = self.state.options },
            Actions { state = self.state.actions }
          }
        }
      }
    end
  }
end

M.deprecated_create = require 'neogit.lib.popup.lib'.create

return M
-- return require("neogit.lib.popup.lib")
