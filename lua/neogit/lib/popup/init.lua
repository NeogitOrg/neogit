local PopupBuilder = require("neogit.lib.popup.builder")
local Buffer = require("neogit.lib.buffer")
local logger = require("neogit.logger")
local util = require("neogit.lib.util")
local state = require("neogit.lib.state")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")
local Watcher = require("neogit.watcher")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local git = require("neogit.lib.git")

local a = require("plenary.async")

local filter_map = util.filter_map
local build_reverse_lookup = util.build_reverse_lookup

local ui = require("neogit.lib.popup.ui")

---@class PopupState

---@class PopupData
---@field state PopupState
---@field buffer Buffer
local M = {}

-- Create a new popup builder
---@return PopupBuilder
function M.builder()
  return PopupBuilder.new(M.new)
end

---@param state PopupState
---@return PopupData
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

    if arg.type == "option" and arg.cli ~= "" and (arg.value and #arg.value ~= 0) and not arg.internal then
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

-- Toggle a switch on/off
---@param switch PopupSwitch
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

    if switch.persisted ~= false then
      state.set({ self.state.name, switch.cli_suffix }, switch.cli)
    end

    return
  end

  switch.enabled = not switch.enabled

  -- If a switch depends on user input, i.e. `-Gsomething`, prompt user to get input
  if switch.user_input then
    if switch.enabled then
      local value = input.get_user_input(switch.cli_prefix .. switch.cli_base, { separator = "" })
      if value then
        switch.cli = switch.cli_base .. value
      end
    else
      switch.cli = switch.cli_base
    end
  end

  if switch.persisted ~= false then
    state.set({ self.state.name, switch.cli }, switch.enabled)
  end

  -- Ensure that other switches/options that are incompatible with this one are disabled
  if switch.enabled and #switch.incompatible > 0 then
    for _, var in ipairs(self.state.args) do
      if switch.incompatible[var.cli] then
        if var.type == "switch" then
          ---@cast var PopupSwitch
          self:disable_switch(var)
        elseif var.type == "option" then
          ---@cast var PopupOption
          self:disable_option(var)
        end
      end
    end
  end

  -- Ensure that switches/options that depend on this one are also disabled
  if not switch.enabled and #switch.dependent > 0 then
    for _, var in ipairs(self.state.args) do
      if switch.dependent[var.cli] then
        if var.type == "switch" then
          ---@cast var PopupSwitch
          self:disable_switch(var)
        elseif var.type == "option" then
          ---@cast var PopupOption
          self:disable_option(var)
        end
      end
    end
  end
end

-- Toggle an option on/off and set it's value
---@param option PopupOption
---@param value? string
---@return nil
function M:set_option(option, value)
  -- Prompt user to select from predetermined choices
  if value then
    option.value = value
  elseif option.choices then
    if not option.value or option.value == "" then
      local eventignore = vim.o.eventignore
      vim.o.eventignore = "WinLeave"
      local choice = FuzzyFinderBuffer.new(option.choices):open_async {
        prompt_prefix = option.description,
      }
      vim.o.eventignore = eventignore

      if choice then
        option.value = choice
      else
        option.value = ""
      end
    else
      option.value = ""
    end
  elseif option.fn then
    option.value = option.fn(self, option)
  else
    local input = input.get_user_input(option.cli, {
      separator = "=",
      default = option.value,
      cancel = option.value,
    })

    -- If the option specifies a default value, and the user set the value to be empty, defer to default value.
    -- This is handy to prevent the user from accidentally loading thousands of log entries by accident.
    if option.default and input == "" then
      option.value = tostring(option.default)
    else
      option.value = input
    end
  end

  state.set({ self.state.name, option.cli }, option.value)

  -- Ensure that other switches/options that are incompatible with this one are disabled
  if option.value and option.value ~= "" and #option.incompatible > 0 then
    for _, var in ipairs(self.state.args) do
      if option.incompatible[var.cli] then
        if var.type == "switch" then
          self:disable_switch(var --[[@as PopupSwitch]])
        elseif var.type == "option" then
          self:disable_option(var --[[@as PopupOption]])
        end
      end
    end
  end

  -- Ensure that switches/options that depend on this one are also disabled
  if option.value and option.value ~= "" and #option.dependent > 0 then
    for _, var in ipairs(self.state.args) do
      if option.dependent[var.cli] then
        if var.type == "switch" then
          self:disable_switch(var --[[@as PopupSwitch]])
        elseif var.type == "option" then
          self:disable_option(var --[[@as PopupOption]])
        end
      end
    end
  end
end

---Disables a switch.
---@param switch PopupSwitch
function M:disable_switch(switch)
  if switch.enabled then
    self:toggle_switch(switch)
  end
end

---Disables an option, setting its value to "". Doesn't use the default, which
---is important to ensure that we don't use incompatible switches/options
---together.
---@param option PopupOption
function M:disable_option(option)
  if option.value and option.value ~= "" then
    self:set_option(option, "")
  end
end

-- Set a config value
---@param config PopupConfig
---@return nil
function M:set_config(config)
  if config.options then
    local options = build_reverse_lookup(filter_map(config.options, function(option)
      if option.condition and not option.condition() then
        return
      end

      return option.value
    end))

    local index = options[config.value or ""] or math.huge
    config.value = options[(index + 1)] or options[1]
    git.config.set(config.name, config.value)
  elseif config.fn then
    config.value = config.fn(self, config)
  else
    local result = input.get_user_input(config.name, { default = config.value, cancel = config.value })

    assert(result, "no input from user - what happened to the default?")
    config.value = result
    git.config.set(config.name, config.value)
  end

  for _, var in ipairs(self.state.config) do
    if var.passive then
      local c_value = git.config.get(var.name)
      if c_value:is_set() then
        var.value = c_value.value
      end
    end
  end

  if config.callback then
    config.callback(self, config)
  end
end

function M:mappings()
  local mappings = {
    n = {
      ["q"] = function()
        self:close()
      end,
      ["<esc>"] = function()
        self:close()
      end,
      ["<tab>"] = a.void(function()
        local component = self.buffer.ui:get_interactive_component_under_cursor()
        if not component then
          return
        end

        if component.options.tag == "Switch" then
          self:toggle_switch(component.options.value)
        elseif component.options.tag == "Config" then
          self:set_config(component.options.value)
        elseif component.options.tag == "Option" then
          self:set_option(component.options.value)
        end

        self:refresh()
      end),
    },
  }

  local arg_prefixes = {}
  for _, arg in pairs(self.state.args) do
    if arg.id then
      arg_prefixes[arg.key_prefix] = true
      mappings.n[arg.id] = a.void(function()
        if arg.type == "switch" then
          ---@cast arg PopupSwitch
          self:toggle_switch(arg)
        elseif arg.type == "option" then
          ---@cast arg PopupOption
          self:set_option(arg)
        end

        self:refresh()
      end)
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
      mappings.n[config.id] = a.void(function()
        self:set_config(config)
        self:refresh()
      end)
    end
  end

  for _, group in pairs(self.state.actions) do
    for _, action in pairs(group) do
      -- selene: allow(empty_if)
      if action.heading then
        -- nothing
      elseif action.callback then
        for _, key in ipairs(action.keys) do
          mappings.n[key] = a.void(function()
            logger.debug(string.format("[POPUP]: Invoking action %q of %s", key, self.state.name))
            self:close()
            action.callback(self)
            Watcher.instance():dispatch_refresh()
          end)
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

  return mappings
end

function M:refresh()
  if self.buffer then
    self.buffer:focus()
    self.buffer.ui:render(unpack(ui.Popup(self.state)))
  end
end

---@return boolean
function M.is_open()
  return (M.instance and M.instance.buffer and M.instance.buffer:is_visible()) == true
end

function M:show()
  if M.is_open() then
    logger.debug("[POPUP] An Instance is already open - closing it")
    M.instance:close()
  end

  M.instance = self

  self.buffer = Buffer.create {
    name = self.state.name,
    filetype = "NeogitPopup",
    kind = "popup",
    mappings = self:mappings(),
    status_column = " ",
    autocmds = {
      ["WinLeave"] = function()
        pcall(self.close, self)
      end,
    },
    after = function(buf)
      buf:set_window_option("cursorline", false)
      buf:set_window_option("list", false)

      if self.state.env.highlight then
        for i = 1, #self.state.env.highlight, 1 do
          vim.fn.matchadd("NeogitPopupBranchName", self.state.env.highlight[i], 100)
        end
      else
        vim.fn.matchadd("NeogitPopupBranchName", git.repo.state.head.branch, 100)
      end

      if self.state.env.bold then
        for i = 1, #self.state.env.bold, 1 do
          vim.fn.matchadd("NeogitPopupBold", self.state.env.bold[i], 100)
        end
      end

      local height = vim.fn.line("$") + 1
      vim.cmd.resize(height)

      -- We do it again because things like the BranchConfigPopup come from an async context,
      -- but if we only do it schedule wrapped, then you can see it load at one size, and
      -- resize a few ms later
      vim.schedule(function()
        if buf:is_focused() then
          vim.cmd.resize(height)
          buf:set_window_option("winfixheight", true)
        end
      end)
    end,
    render = function()
      return ui.Popup(self.state)
    end,
  }
end

return M
