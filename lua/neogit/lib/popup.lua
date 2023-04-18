local PopupBuilder = require("neogit.lib.popup.builder")
local Buffer = require("neogit.lib.buffer")
local common = require("neogit.buffers.common")
local Ui = require("neogit.lib.ui")
local logger = require("neogit.logger")
local util = require("neogit.lib.util")
local config = require("neogit.config")
local state = require("neogit.lib.state")

local branch = require("neogit.lib.git.branch")
local config_lib = require("neogit.lib.git.config")

local col = Ui.col
local row = Ui.row
local text = Ui.text
local Component = Ui.Component
local map = util.map
local filter_map = util.filter_map
local build_reverse_lookup = util.build_reverse_lookup
local intersperse = util.intersperse
local List = common.List
local Grid = common.Grid

local M = {}

function M.builder()
  return PopupBuilder.new(M.new)
end

function M.new(state)
  local instance = {
    state = state,
    buffer = nil,
  }
  setmetatable(instance, { __index = M })
  return instance
end

---@return string[]
function M:get_arguments()
  local flags = {}

  for _, switch in pairs(self.state.switches) do
    if switch.enabled and switch.parse ~= false then
      table.insert(flags, switch.cli_prefix .. switch.cli)
    end
  end

  for _, option in pairs(self.state.options) do
    if #option.value ~= 0 and option.parse ~= false then
      table.insert(flags, option.cli_prefix .. option.cli .. "=" .. option.value)
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

local function get_highlight_for_config(config)
  if config.value and config.value ~= "" and config.value ~= "unset" then
    return config.type or "NeogitPopupConfigEnabled"
  end

  return "NeogitPopupConfigDisabled"
end

local function construct_config_options(config)
  local options = filter_map(config.options, function(option)
    if option.display == "" then
      return
    end

    local highlight
    if config.value == option.value then
      highlight = "NeogitPopupConfigEnabled"
    else
      highlight = "NeogitPopupConfigDisabled"
    end

    return text.highlight(highlight)(option.display)
  end)

  local value = intersperse(options, text.highlight("NeogitPopupConfigDisabled")("|"))
  table.insert(value, 1, text.highlight("NeogitPopupConfigDisabled")("["))
  table.insert(value, #value + 1, text.highlight("NeogitPopupConfigDisabled")("]"))

  return value
end

function M:update_component(id, highlight, value)
  local component = self.buffer.ui:find_component(function(c)
    return c.options.id == id
  end)

  assert(component, "Component not found! Cannot update.")

  if highlight then
    if component.options.highlight then
      component.options.highlight = highlight
    else
      component.children[1].options.highlight = highlight
    end
  end

  if value then
    if type(value) == "string" then
      component.children[#component.children].value = value
    elseif type(value) == "table" then
      -- Remove last n children from row
      for _ = 1, #value do
        table.remove(component.children)
      end

      -- insert new items to row
      for _, text in ipairs(value) do
        table.insert(component.children, text)
      end
    else
      print("Unhandled component value type! (" .. type(value) .. ")")
    end
  end

  self.buffer.ui:update()
end

function M:toggle_switch(switch)
  switch.enabled = not switch.enabled

  state.set({ self.state.name, switch.cli }, switch.enabled)
  self:update_component(switch.id, get_highlight_for_switch(switch))

  if switch.enabled and #switch.incompatible > 0 then
    for _, var in ipairs(self.state.switches) do
      if var.enabled and switch.incompatible[var.cli] then
        var.enabled = false
        state.set({ self.state.name, var.cli }, var.enabled)
        self:update_component(var.id, get_highlight_for_switch(var))
      end
    end
  end
end

function M:set_option(option)
  local set = function(value)
    option.value = value
    state.set({ self.state.name, option.cli }, option.value)
    self:update_component(option.id, get_highlight_for_option(option), option.value)
  end

  if option.choices then
    if not option.value or option.value == "" then
      vim.ui.select(option.choices, { prompt = option.description }, set)
    else
      set("")
    end
  else
    set(vim.fn.input {
      prompt = option.cli .. "=",
      default = option.value,
      cancelreturn = option.value,
    })
  end
end

function M:set_config(config)
  if config.options then
    local options = build_reverse_lookup(map(config.options, function(option)
      return option.value
    end))

    local index = options[config.value]
    config.value = options[(index + 1)] or options[1]
    self:update_component(config.id, nil, construct_config_options(config))
  elseif config.callback then
    config.callback(self, config)
    -- block here?
  else
    local result = vim.fn.input {
      prompt = config.name .. " > ",
      default = config.value == "unset" and "" or config.value,
      cancelreturn = config.value,
    }

    config.value = result == "" and "unset" or result
    self:update_component(config.id, get_highlight_for_config(config), config.value)
  end

  config_lib.set(config.name, config.value)

  -- Updates passive variables (variables that don't get interacted with directly)
  for _, var in ipairs(self.state.config) do
    if var.passive then
      local c_value = config_lib.get(var.name)
      if c_value then
        var.value = c_value.value
        self:update_component(var.id, nil, var.value)
      end
    end
  end
end

local Switches = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle")("Switches"),
    col(map(props.state, function(switch)
      return row.tag("Switch").value(switch) {
        row.highlight("NeogitPopupSwitchKey") {
          text(" -"),
          text(switch.key),
        },
        text(" "),
        text(switch.description),
        text(" ("),
        row.id(switch.id).highlight(get_highlight_for_switch(switch)) {
          text(switch.cli_prefix),
          text(switch.cli),
        },
        text(")"),
      }
    end)),
  }
end)

local Options = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle")("Options"),
    col(map(props.state, function(option)
      return row.tag("Option").value(option) {
        text(" "),
        row.highlight("NeogitPopupOptionKey") {
          text("="),
          text(option.key),
        },
        text(" "),
        text(option.description),
        text(" ("),
        row.id(option.id).highlight(get_highlight_for_option(option)) {
          text(option.cli_prefix),
          text(option.cli),
          text("="),
          text(option.value or ""),
        },
        text(")"),
      }
    end)),
  }
end)

local Config = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle")("Variables"),
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

      return row.tag("Config").value(config) {
        text(" "),
        row.highlight("NeogitPopupConfigKey") {
          text(not config.passive and config.key or " "),
        },
        text(" " .. config.name .. " "),
        row.id(config.id) { unpack(value) },
      }
    end)),
  }
end)

local Actions = Component.new(function(props)
  return col {
    Grid.padding_left(1) {
      items = props.state,
      gap = 3,
      render_item = function(item)
        if item.heading then
          return row.highlight("NeogitPopupSectionTitle") { text(item.heading) }
        elseif not item.callback then
          return row.highlight("NeogitPopupActionDisabled") {
            text(" "),
            text(item.key),
            text(" "),
            text(item.description),
          }
        else
          return row {
            text(" "),
            text.highlight("NeogitPopupActionKey")(item.key),
            text(" "),
            text(item.description),
          }
        end
      end,
    },
  }
end)

function M:show()
  local mappings = {
    n = {
      ["q"] = function()
        self:close()
      end,
      ["<esc>"] = function()
        self:close()
      end,
      ["<tab>"] = function()
        local stack = self.buffer.ui:get_component_stack_under_cursor()

        for _, x in ipairs(stack) do
          if x.options.tag == "Switch" then
            self:toggle_switch(x.options.value)
            break
          elseif x.options.tag == "Config" then
            self:set_config(x.options.value)
            break
          elseif x.options.tag == "Option" then
            self:set_option(x.options.value)
            break
          end
        end
      end,
    },
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

  for _, config in pairs(self.state.config) do
    if config.heading then
      -- nothing
    elseif not config.passive then
      mappings.n[config.id] = function()
        self:set_config(config)
      end
    end
  end

  for _, group in pairs(self.state.actions) do
    for _, action in pairs(group) do
      if action.heading then
        -- nothing
      elseif action.callback then
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
          local notif = require("neogit.lib.notification")
          notif.create(action.description .. " has not been implemented yet", vim.log.levels.WARN)
        end
      end
    end
  end

  local items = {}

  if self.state.config[1] then
    table.insert(items, Config { state = self.state.config })
  end

  if self.state.switches[1] then
    table.insert(items, Switches { state = self.state.switches })
  end

  if self.state.options[1] then
    table.insert(items, Options { state = self.state.options })
  end

  if self.state.actions[1] then
    table.insert(items, Actions { state = self.state.actions })
  end

  self.buffer = Buffer.create {
    name = self.state.name,
    filetype = "NeogitPopup",
    kind = config.values.popup.kind,
    mappings = mappings,
    after = function(buffer)
      vim.api.nvim_buf_call(buffer.handle, function()
        vim.cmd([[setlocal nocursorline]])
        vim.fn.matchadd("NeogitPopupBranchName", branch.current(), 100)
      end)

      if config.values.popup.kind == "split" then
        vim.api.nvim_buf_call(buffer.handle, function()
          vim.cmd([[execute "resize" . (line("$") + 1)]])
        end)
      end
    end,
    render = function()
      return {
        List {
          separator = "",
          items = items,
        },
      }
    end,
  }
end

return M
