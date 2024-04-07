local M = {}

local common = require("neogit.buffers.common")
local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")

local EmptyLine = common.EmptyLine
local List = common.List
local Grid = common.Grid
local col = Ui.col
local row = Ui.row
local text = Ui.text
local Component = Ui.Component

local intersperse = util.intersperse
local filter_map = util.filter_map
local map = util.map

-- Builds config component to be rendered
---@return table
local function construct_config_options(config, prefix, suffix)
  local set = false
  local options = filter_map(config.options, function(option)
    if option.display == "" then
      return
    end

    if option.condition and not option.condition() then
      return
    end

    local highlight
    if config.value == option.value then
      set = true
      highlight = "NeogitPopupConfigEnabled"
    else
      highlight = "NeogitPopupConfigDisabled"
    end

    return text.highlight(highlight)(option.display)
  end)

  local value = intersperse(options, text.highlight("NeogitPopupConfigDisabled")("|"))
  table.insert(value, 1, text.highlight("NeogitPopupConfigDisabled")("["))
  table.insert(value, #value + 1, text.highlight("NeogitPopupConfigDisabled")("]"))

  if prefix then
    table.insert(
      value,
      1,
      text.highlight(set and "NeogitPopupConfigEnabled" or "NeogitPopupConfigDisabled")(prefix)
    )
  end

  if suffix then
    table.insert(
      value,
      #value + 1,
      text.highlight(set and "NeogitPopupConfigEnabled" or "NeogitPopupConfigDisabled")(suffix)
    )
  end

  return value
end

-- Determines the correct highlight group for a switch based on it's state.
---@return string
local function get_highlight_for_switch(switch)
  if switch.enabled then
    return "NeogitPopupSwitchEnabled"
  end

  return "NeogitPopupSwitchDisabled"
end

-- Determines the correct highlight group for an option based on it's state.
---@return string
local function get_highlight_for_option(option)
  if option.value ~= nil and option.value ~= "" then
    return "NeogitPopupOptionEnabled"
  end

  return "NeogitPopupOptionDisabled"
end

-- Determines the correct highlight group for a config based on it's type and state.
---@return string
local function get_highlight_for_config(config)
  if config.value and config.value ~= "" then
    return config.type or "NeogitPopupConfigEnabled"
  end

  return "NeogitPopupConfigDisabled"
end

local Switch = Component.new(function(switch)
  local value
  if switch.options then
    value = row.id(switch.id)(construct_config_options(switch, switch.cli_prefix, switch.cli_suffix))
  else
    value = row
      .id(switch.id)
      .highlight(get_highlight_for_switch(switch)) { text(switch.cli_prefix), text(switch.cli) }
  end

  return row.tag("Switch").value(switch)({
    row.highlight("NeogitPopupSwitchKey") {
      text(switch.key_prefix),
      text(switch.key),
    },
    text(" "),
    text(switch.description),
    text(" ("),
    value,
    text(")"),
  }, { interactive = true })
end)

local Option = Component.new(function(option)
  return row.tag("Option").value(option)({
    row.highlight("NeogitPopupOptionKey") {
      text(option.key_prefix),
      text(option.key),
    },
    text(" "),
    text(option.description),
    text(" ("),
    row.id(option.id).highlight(get_highlight_for_option(option)) {
      text(option.cli_prefix),
      text(option.cli),
      text(option.separator),
      text(option.value or ""),
    },
    text(")"),
  }, { interactive = true })
end)

local Section = Component.new(function(title, items)
  return col {
    text.highlight("NeogitPopupSectionTitle")(title),
    col(items),
  }
end)

local Config = Component.new(function(props)
  local c = {}

  if not props.state[1].heading then
    table.insert(c, text.highlight("NeogitPopupSectionTitle")("Variables"))
  end

  table.insert(
    c,
    col(map(props.state, function(config)
      if config.heading then
        return row.highlight("NeogitPopupSectionTitle") { text(config.heading) }
      end

      local value
      if config.options then
        value = construct_config_options(config)
      else
        local value_text
        if not config.value or config.value == "" then
          value_text = "unset"
        else
          value_text = config.value
        end

        value = { text.highlight(get_highlight_for_config(config))(value_text) }
      end

      local key
      if config.passive then
        key = " "
      elseif #config.key > 1 then
        key = table.concat(vim.split(config.key, ""), " ")
      else
        key = config.key
      end

      return row.tag("Config").value(config)({
        row.highlight("NeogitPopupConfigKey") { text(key) },
        text(" " .. config.name .. " "),
        row.id(config.id) { unpack(value) },
      }, { interactive = true })
    end))
  )

  return col(c)
end)

local function render_action(action)
  local items = {}

  -- selene: allow(empty_if)
  if action.keys == nil then
    -- Action group heading
  elseif #action.keys == 0 then
    table.insert(items, text.highlight("NeogitPopupActionDisabled")("_"))
  else
    for i, key in ipairs(action.keys) do
      table.insert(items, text.highlight("NeogitPopupActionKey")(key))
      if i < #action.keys then
        table.insert(items, text(","))
      end
    end
  end

  table.insert(items, text(" "))
  table.insert(items, text(action.description))

  return items
end

local Actions = Component.new(function(props)
  return col {
    Grid.padding_left(1) {
      items = props.state,
      gap = 3,
      render_item = function(item)
        if item.heading then
          return row.highlight("NeogitPopupSectionTitle") { text(item.heading) }
        elseif not item.callback then
          return row.highlight("NeogitPopupActionDisabled")(render_action(item))
        else
          return row(render_action(item))
        end
      end,
    },
  }
end)

function M.items(state)
  local items = {}

  if state.config[1] then
    table.insert(items, Config { state = state.config })
    table.insert(items, EmptyLine())
  end

  if state.args[1] then
    local section = {}
    local name = "Arguments"
    for _, item in ipairs(state.args) do
      if item.type == "option" then
        table.insert(section, Option(item))
      elseif item.type == "switch" then
        table.insert(section, Switch(item))
      elseif item.type == "heading" then
        if section[1] then -- If there are items in the section, flush to items table with current name
          table.insert(items, Section(name, section))
          table.insert(items, EmptyLine())
          section = {}
        end

        name = item.heading
      end
    end

    table.insert(items, Section(name, section))
    table.insert(items, EmptyLine())
  end

  if state.actions[1] then
    table.insert(items, Actions { state = state.actions })
  end

  return items
end

function M.Popup(state)
  return {
    List {
      items = M.items(state),
    },
  }
end

return M
