local git = require("neogit.lib.git")
local state = require("neogit.lib.state")
local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")
local config = require("neogit.config")

---@class PopupBuilder
---@field state PopupState
---@field builder_fn PopupData
local M = {}

---@class PopupState
---@field name string
---@field args PopupOption[]|PopupSwitch[]|PopupHeading[]
---@field config PopupConfig[]
---@field actions PopupAction[][]
---@field env table
---@field keys table<string, boolean>

---@class PopupHeading
---@field type string
---@field heading string

---@class PopupOption
---@field choices table
---@field cli string
---@field cli_prefix string
---@field default string|integer|boolean
---@field dependent table
---@field description string
---@field fn function
---@field id string
---@field incompatible table
---@field key string
---@field key_prefix string
---@field separator string
---@field type string
---@field value string?

---@class PopupSwitch
---@field cli string
---@field cli_base string
---@field cli_prefix string
---@field cli_suffix string
---@field dependent table
---@field description string
---@field enabled boolean
---@field fn function
---@field id string
---@field incompatible string[]
---@field internal boolean
---@field key string
---@field key_prefix string
---@field options table
---@field type string
---@field user_input boolean
---@field value string?
---@field persisted? boolean

---@class PopupConfig
---@field id string
---@field key string
---@field name string
---@field entry ConfigEntry
---@field value string?
---@field type string
---@field passive boolean?
---@field heading string?
---@field options PopupConfigOption[]?
---@field callback fun(popup: PopupData, config: self)? Called after the config is set
---@field fn fun(popup: PopupData, config: self)? If set, overrides the actual config setting behavior

---@class PopupConfigOption An option that can be selected as a value for a config
---@field display string The display name for the option
---@field value string The value to set in git config
---@field condition? fun(): boolean An option predicate to determine if the option should appear

---@class PopupAction
---@field keys string[]
---@field description string
---@field callback function
---@field heading string?

---@class PopupSwitchOpts
---@field enabled? boolean Controls if the switch should default to 'on' state
---@field internal? boolean Whether the switch is internal to neogit or should be included in the cli command. If `true` we don't include it in the cli command.
---@field incompatible? string[] A table of strings that represent other cli switches/options that this one cannot be used with
---@field key_prefix? string Allows overwriting the default '-' to toggle switch
---@field cli_prefix? string Allows overwriting the default '--' that's used to create the cli flag. Sometimes you may want to use '++' or '-'.
---@field cli_suffix? string
---@field options? table
---@field value? string Allows for pre-building cli flags that can be customized by user input
---@field user_input? boolean If true, allows user to customize the value of the cli flag
---@field dependent? string[] other switches/options with a state dependency on this one
---@field persisted? boolean Allows overwriting the default 'true' to decide if this switch should be persisted

---@class PopupOptionOpts
---@field key_prefix? string Allows overwriting the default '=' to set option
---@field cli_prefix? string Allows overwriting the default '--' cli prefix
---@field choices? table Table of predefined choices that a user can select for option
---@field default? string|integer|boolean Default value for option, if the user attempts to unset value
---@field dependent? string[] other switches/options with a state dependency on this one
---@field incompatible? string[] A table of strings that represent other cli switches/options that this one cannot be used with
---@field separator? string Defaults to `=`, separating the key from the value. Some CLI options are weird.
---@field setup? fun(PopupBuilder) function called before rendering
---@field fn? fun() function called - like an action. Used to launch a popup from a popup.

---@class PopupConfigOpts
---@field options? PopupConfigOption[]
---@field fn? fun(popup: PopupData, config: self) If set, overrides the actual config setting behavior
---@field callback? fun(popup: PopupData, config: PopupConfig)? A callback that will be invoked after the config is set
---@field passive? boolean? Controls if this config setting can be manipulated directly, or if it is managed by git, and should just be shown in UI
---                       A 'condition' key with function value can also be present in the option, which controls if the option gets shown by returning boolean.

---@param builder_fn fun(): PopupData
---@return PopupBuilder
function M.new(builder_fn)
  local instance = {
    state = {
      name = nil,
      args = {},
      config = {},
      actions = { {} },
      env = {},
      keys = {},
    },
    builder_fn = builder_fn,
  }

  setmetatable(instance, { __index = M })

  return instance
end

-- Set the popup's name. This must be set for all popups.
---@param name string The name
---@return self
function M:name(name)
  self.state.name = name
  return self
end

-- Set initial context for the popup
---@param env table The initial context
---@return self
function M:env(env)
  self.state.env = env or {}
  return self
end

-- adds a new column to the actions section of the popup
---@param heading string?
---@return self
function M:new_action_group(heading)
  table.insert(self.state.actions, { { heading = heading or "" } })
  return self
end

-- Conditionally adds a new column to the actions section of the popup
---@param cond boolean
---@param heading string?
---@return self
function M:new_action_group_if(cond, heading)
  if cond then
    return self:new_action_group(heading)
  end

  return self
end

-- adds a new heading to current column within the actions section of the popup
---@param heading string
---@return self
function M:group_heading(heading)
  table.insert(self.state.actions[#self.state.actions], { heading = heading })
  return self
end

-- Conditionally adds a new heading to current column within the actions section of the popup
---@param cond boolean
---@param heading string
---@return self
function M:group_heading_if(cond, heading)
  if cond then
    return self:group_heading(heading)
  end

  return self
end

-- Adds a switch to the popup
---@param key string Which key triggers switch
---@param cli string Git cli flag to use
---@param description string Description text to show user
---@param opts PopupSwitchOpts? Additional options
---@return self
function M:switch(key, cli, description, opts)
  opts = opts or {}

  if opts.enabled == nil then
    opts.enabled = false
  end

  if opts.internal == nil then
    opts.internal = false
  end

  if opts.incompatible == nil then
    opts.incompatible = {}
  end

  if opts.dependent == nil then
    opts.dependent = {}
  end

  if opts.key_prefix == nil then
    opts.key_prefix = "-"
  end

  if opts.cli_prefix == nil then
    opts.cli_prefix = "--"
  end

  if opts.cli_suffix == nil then
    opts.cli_suffix = ""
  end

  if opts.persisted == nil then
    opts.persisted = true
  end

  local value
  if opts.enabled and opts.value then
    value = cli .. opts.value
  elseif opts.options and opts.cli_suffix ~= "" then
    value = state.get({ self.state.name, opts.cli_suffix }, cli)
  else
    value = cli
  end

  local enabled
  if opts.options then
    enabled = state.get({ self.state.name, opts.cli_suffix }, "") ~= ""
  else
    enabled = state.get({ self.state.name, cli }, opts.enabled)
  end

  ---@type PopupSwitch
  table.insert(self.state.args, {
    type = "switch",
    id = opts.key_prefix .. key,
    key = key,
    key_prefix = opts.key_prefix,
    cli = value,
    value = value, -- Only used with options. Needed to keep the construct_config_options() fn simple.
    cli_base = cli,
    description = description,
    enabled = enabled,
    internal = opts.internal,
    cli_prefix = opts.cli_prefix,
    user_input = opts.user_input,
    cli_suffix = opts.cli_suffix,
    persisted = opts.persisted,
    options = opts.options,
    incompatible = util.build_reverse_lookup(opts.incompatible),
    dependent = util.build_reverse_lookup(opts.dependent),
  })

  return self
end

-- Conditionally adds a switch to the popup
---@see M:switch
---@param cond boolean The condition under which to add the config
---@param key string Which key triggers switch
---@param cli string Git cli flag to use
---@param description string Description text to show user
---@param opts PopupSwitchOpts? Additional options
---@return self
function M:switch_if(cond, key, cli, description, opts)
  if cond then
    return self:switch(key, cli, description, opts)
  end

  return self
end

-- Adds an option to the popup
---@param key string Key for the user to engage option
---@param cli string CLI value used
---@param value string Current value of option
---@param description string Description of option, presented to user
---@param opts PopupOptionOpts? Additional options
function M:option(key, cli, value, description, opts)
  opts = opts or {}

  if opts.key_prefix == nil then
    opts.key_prefix = "="
  end

  if opts.cli_prefix == nil then
    opts.cli_prefix = "--"
  end

  if opts.separator == nil then
    opts.separator = "="
  end

  if opts.dependent == nil then
    opts.dependent = {}
  end

  if opts.incompatible == nil then
    opts.incompatible = {}
  end

  if opts.setup then
    opts.setup(self)
  end

  ---@type PopupOption
  table.insert(self.state.args, {
    type = "option",
    id = opts.key_prefix .. key,
    key = key,
    key_prefix = opts.key_prefix,
    cli = cli,
    value = state.get({ self.state.name, cli }, value),
    description = description,
    cli_prefix = opts.cli_prefix,
    choices = opts.choices,
    default = opts.default,
    separator = opts.separator,
    dependent = util.build_reverse_lookup(opts.dependent),
    incompatible = util.build_reverse_lookup(opts.incompatible),
    fn = opts.fn,
  })

  return self
end

-- adds a heading text within Arguments (options/switches) section of the popup
---@param heading string Heading to show
---@return self
function M:arg_heading(heading)
  table.insert(self.state.args, { type = "heading", heading = heading })
  return self
end

-- Conditionally adds an option to the popup
---@see M:option
---@param cond boolean The condition under which to add the config
---@param key string Which key triggers switch
---@param cli string Git cli flag to use
---@param description string Description text to show user
---@param opts PopupOptionOpts? Additional options
---@return self
function M:option_if(cond, key, cli, value, description, opts)
  if cond then
    return self:option(key, cli, value, description, opts)
  end

  return self
end

-- adds a heading text with the config section of the popup
---@param heading string Heading to render
---@return self
function M:config_heading(heading)
  table.insert(self.state.config, { heading = heading })
  return self
end

-- adds a heading text with the config section of the popup
---@param cond boolean
---@param heading string Heading to render
---@return self
function M:config_heading_if(cond, heading)
  if cond then
    table.insert(self.state.config, { heading = heading })
  end

  return self
end

-- Adds config to the popup
---@param key string Key for user to use that engages config
---@param name string Name of config
---@param options PopupConfigOpts? Additional options
---@return self
function M:config(key, name, options)
  local entry = git.config.get(name)

  ---@type PopupConfig
  local variable = {
    id = key,
    key = key,
    name = name,
    entry = entry,
    value = entry.value or "",
    type = entry:type(),
  }

  for k, v in pairs(options or {}) do
    variable[k] = v
  end

  table.insert(self.state.config, variable)

  return self
end

-- Conditionally adds config to the popup
---@see M:config
---@param cond boolean The condition under which to add the config
---@param key string Key for user to use that engages config
---@param name string Name of config
---@param options PopupConfigOpts? Additional options
---@return self
function M:config_if(cond, key, name, options)
  if cond then
    return self:config(key, name, options)
  end

  return self
end

-- Adds an action to the popup
---@param keys string|string[] Key or list of keys for the user to press that runs the action
---@param description string Description of action in UI
---@param callback? fun(popup: PopupData) Function that gets run in async context
---@return self
function M:action(keys, description, callback)
  if type(keys) == "string" then
    keys = { keys }
  end

  for _, key in pairs(keys) do
    if self.state.keys[key] then
      notification.error(string.format("[POPUP] Duplicate key mapping %q", key))
      return self
    end

    self.state.keys[key] = true
  end

  table.insert(self.state.actions[#self.state.actions], {
    keys = keys,
    description = description,
    callback = callback,
  })

  return self
end

-- Conditionally adds an action to the popup
---@see M:action
---@param cond boolean The condition under which to add the action
---@param keys string|string[] Key or list of keys for the user to press that runs the action
---@param description string Description of action in UI
---@param callback? fun(popup: PopupData) Function that gets run in async context
---@return self
function M:action_if(cond, keys, description, callback)
  if cond then
    return self:action(keys, description, callback)
  end

  return self
end

-- Builds the popup
---@return PopupData # The popup
function M:build()
  if self.state.name == nil then
    error("A popup needs to have a name!")
  end

  if config.values.builders ~= nil and type(config.values.builders[self.state.name]) == "function" then
    config.values.builders[self.state.name](self)
  end

  return self.builder_fn(self.state)
end

return M
