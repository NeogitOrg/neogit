local PopupBuilder = require("neogit.lib.popup.builder")
local Buffer = require("neogit.lib.buffer")
local common = require("neogit.buffers.common")
local Ui = require("neogit.lib.ui")
local logger = require("neogit.logger")
local util = require("neogit.lib.util")
local config = require("neogit.config")
local state = require("neogit.lib.state")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")

local git = require("neogit.lib.git")

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

-- Returns a table of strings, each representing a toggled option/switch in the popup. Filters out internal arguments.
-- Formatted for consumption by cli:
-- Option: --name=value
-- Switch: --name
---@return string[]
function M:get_arguments()
  local flags = {}

  for _, arg in pairs(self.state.args) do
    if arg.type == "switch" and arg.enabled and not arg.internal then
      table.insert(flags, arg.cli_prefix .. arg.cli .. arg.cli_suffix)
    end

    if arg.type == "option" and arg.cli ~= "" and #arg.value ~= 0 and not arg.internal then
      table.insert(flags, arg.cli_prefix .. arg.cli .. "=" .. arg.value)
    end
  end

  return flags
end

-- Returns a table of key/value pairs, where the key is the name of the switch, and value is `true`, for all
-- enabled arguments that are NOT for cli consumption (internal use only).
---@return table
function M:get_internal_arguments()
  local args = {}
  for _, arg in pairs(self.state.args) do
    if arg.type == "switch" and arg.enabled and arg.internal then
      args[arg.cli] = true
    end
  end
  return args
end

-- Combines all cli arguments into a single string.
---@return string
function M:to_cli()
  return table.concat(self:get_arguments(), " ")
end

-- Closes the popup buffer
function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end
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

---@param id integer ID of component to be updated
---@param highlight string New highlight group for value
---@param value string|table New value to display
---@return nil
function M:update_component(id, highlight, value)
  local component = self.buffer.ui:find_component(function(c)
    return c.options.id == id
  end)

  assert(component, "Component not found! Cannot update.")

  if highlight then
    if component.options.highlight then
      component.options.highlight = highlight
    elseif component.children then
      component.children[1].options.highlight = highlight
    end
  end

  if type(value) == "string" then
    local new
    if value == "" then
      local last_child = component.children[#component.children - 1]
      if (last_child and last_child.value == "=") or component.options.id == "--" then
        -- Check if this is a CLI option - the value should get blanked out for these
        new = ""
      else
        -- If the component is NOT a cli option, use "unset" string
        new = "unset"
      end
    else
      new = value
    end

    component.children[#component.children].value = new
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
    logger.error(string.format("[POPUP]: Unhandled component value type! (%s)", type(value)))
  end

  self.buffer.ui:update()
end

-- Toggle a switch on/off
---@param switch table
---@return nil
function M:toggle_switch(switch)
  if switch.options then
    local options = build_reverse_lookup(filter_map(switch.options, function(option)
      if option.condition and not option.condition() then
        return
      end

      return option.value
    end))

    local index = options[switch.cli or ""]
    switch.cli = options[(index + 1)] or options[1]
    switch.value = switch.cli

    switch.enabled = switch.cli ~= ""

    state.set({ self.state.name, switch.cli_suffix }, switch.cli)
    self:update_component(
      switch.id,
      get_highlight_for_switch(switch),
      construct_config_options(switch, switch.cli_prefix, switch.cli_suffix)
    )

    return
  end

  switch.enabled = not switch.enabled

  -- If a switch depends on user input, i.e. `-Gsomething`, prompt user to get input
  if switch.user_input then
    if switch.enabled then
      local value = input.get_user_input(switch.cli_prefix .. switch.cli_base .. ": ")
      if value then
        switch.cli = switch.cli_base .. value
      end
    else
      switch.cli = switch.cli_base
    end
  end

  -- Update internal state and UI.
  state.set({ self.state.name, switch.cli }, switch.enabled)
  self:update_component(switch.id, get_highlight_for_switch(switch), switch.cli)

  -- Ensure that other switches that are incompatible with this one are disabled
  if switch.enabled and #switch.incompatible > 0 then
    for _, var in ipairs(self.state.args) do
      if var.type == "switch" and var.enabled and switch.incompatible[var.cli] then
        var.enabled = false
        state.set({ self.state.name, var.cli }, var.enabled)
        self:update_component(var.id, get_highlight_for_switch(var))
      end
    end
  end

  -- Ensure that switches that depend on this one are also disabled
  if not switch.enabled and #switch.dependant > 0 then
    for _, var in ipairs(self.state.args) do
      if var.type == "switch" and var.enabled and switch.dependant[var.cli] then
        var.enabled = false
        state.set({ self.state.name, var.cli }, var.enabled)
        self:update_component(var.id, get_highlight_for_switch(var))
      end
    end
  end
end

-- Toggle an option on/off and set it's value
---@param option table
---@return nil
function M:set_option(option)
  local set = function(value)
    option.value = value
    state.set({ self.state.name, option.cli }, option.value)
    self:update_component(option.id, get_highlight_for_option(option), option.value)
  end

  -- Prompt user to select from predetermined choices
  if option.choices then
    if not option.value or option.value == "" then
      vim.ui.select(option.choices, { prompt = option.description }, set)
    else
      set("")
    end
  elseif option.fn then
    option.fn(self, option, set)
  else
    -- ...Otherwise get the value via input.
    local input = vim.fn.input {
      prompt = option.cli .. "=",
      default = option.value,
      cancelreturn = option.value,
    }

    -- If the option specifies a default value, and the user set the value to be empty, defer to default value.
    -- This is handy to prevent the user from accidentally loading thousands of log entries by accident.
    if option.default and input == "" then
      set(option.default)
    else
      set(input)
    end
  end
end

-- Set a config value
---@param config table
---@return nil
function M:set_config(config)
  if config.options then
    local options = build_reverse_lookup(filter_map(config.options, function(option)
      if option.condition and not option.condition() then
        return
      end

      return option.value
    end))

    local index = options[config.value or ""]
    config.value = options[(index + 1)] or options[1]
  elseif config.fn then
    config.fn(self, config)
    return
  else
    local result = vim.fn.input {
      prompt = config.name .. " > ",
      default = config.value,
      cancelreturn = config.value,
    }

    config.value = result
  end

  git.config.set(config.name, config.value)

  self:repaint_config()

  if config.callback then
    config.callback(self, config)
  end
end

function M:repaint_config()
  for _, var in ipairs(self.state.config) do
    if var.passive then
      local c_value = git.config.get(var.name)
      if c_value:is_set() then
        var.value = c_value.value
        self:update_component(var.id, nil, var.value)
      end
    elseif var.options then
      self:update_component(var.id, nil, construct_config_options(var))
    else
      self:update_component(var.id, get_highlight_for_config(var), var.value)
    end
  end
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

  return row.tag("Switch").value(switch) {
    text(" "),
    row.highlight("NeogitPopupSwitchKey") {
      text(switch.key_prefix),
      text(switch.key),
    },
    text(" "),
    text(switch.description),
    text(" ("),
    value,
    text(")"),
  }
end)

local Option = Component.new(function(option)
  return row.tag("Option").value(option) {
    text(" "),
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
  }
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

      return row.tag("Config").value(config) {
        text(" "),
        row.highlight("NeogitPopupConfigKey") { text(key) },
        text(" " .. config.name .. " "),
        row.id(config.id) { unpack(value) },
      }
    end))
  )

  return col(c)
end)

local function render_action(action)
  local items = {
    text(" "),
  }

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

  local arg_prefixes = {}
  for _, arg in pairs(self.state.args) do
    if arg.id then
      arg_prefixes[arg.key_prefix] = true
      mappings.n[arg.id] = function()
        if arg.type == "switch" then
          self:toggle_switch(arg)
        elseif arg.type == "option" then
          self:set_option(arg)
        end
      end
    end
  end
  for prefix, _ in pairs(arg_prefixes) do
    mappings.n[prefix] = function()
      local c = vim.fn.getcharstr()
      if mappings.n[prefix .. c] then
        mappings.n[prefix .. c]()
      end
    end
  end

  for _, config in pairs(self.state.config) do
    -- selene: allow(empty_if)
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
      -- selene: allow(empty_if)
      if action.heading then
        -- nothing
      elseif action.callback then
        for _, key in ipairs(action.keys) do
          mappings.n[key] = function()
            logger.debug(string.format("[POPUP]: Invoking action '%s' of %s", key, self.state.name))
            action.callback(self)
            self:close()
          end
        end
      else
        for _, key in ipairs(action.keys) do
          mappings.n[key] = function()
            notification.warn(action.description .. " has not been implemented yet")
          end
        end
      end
    end
  end

  local items = {}

  if self.state.config[1] then
    table.insert(items, Config { state = self.state.config })
  end

  if self.state.args[1] then
    local section = {}
    local name = "Arguments"
    for _, item in ipairs(self.state.args) do
      if item.type == "option" then
        table.insert(section, Option(item))
      elseif item.type == "switch" then
        table.insert(section, Switch(item))
      elseif item.type == "heading" then
        if section[1] then -- If there are items in the section, flush to items table with current name
          table.insert(items, Section(name, section))
          section = {}
        end

        name = item.heading
      end
    end

    table.insert(items, Section(name, section))
  end

  if self.state.actions[1] then
    table.insert(items, Actions { state = self.state.actions })
  end

  self.buffer = Buffer.create {
    name = self.state.name,
    filetype = "NeogitPopup",
    kind = config.values.popup.kind,
    mappings = mappings,
    after = function(buf, win)
      vim.api.nvim_set_option_value("cursorline", false, { win = win })
      vim.api.nvim_set_option_value("list", false, { win = win })

      if self.state.env.highlight then
        for i = 1, #self.state.env.highlight, 1 do
          vim.fn.matchadd("NeogitPopupBranchName", self.state.env.highlight[i], 100)
        end
      else
        vim.fn.matchadd("NeogitPopupBranchName", git.repo.head.branch, 100)
      end

      if self.state.env.bold then
        for i = 1, #self.state.env.bold, 1 do
          vim.fn.matchadd("NeogitPopupBold", self.state.env.bold[i], 100)
        end
      end

      if config.values.popup.kind == "split" or config.values.popup.kind == "split_above" then
        vim.cmd.resize(vim.fn.line("$") + 1)

        -- We do it again because things like the BranchConfigPopup come from an async context,
        -- but if we only do it schedule wrapped, then you can see it load at one size, and
        -- resize a few ms later
        vim.schedule(function()
          if buf:is_focused() then
            vim.cmd.resize(vim.fn.line("$") + 1)
          end
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
    autocmds = {
      ["WinLeave"] = function()
        if self.buffer.kind == "floating" then
          -- We pcall this because it's possible the window was closed by a command invocation, e.g. "cc" for commits
          pcall(self.close, self)
        end
      end,
    },
  }
end

return M
