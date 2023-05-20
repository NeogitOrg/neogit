local a = require("plenary.async")
local state = require("neogit.lib.state")
local config = require("neogit.lib.git.config")
local util = require("neogit.lib.util")

local M = {}

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

function M:name(x)
  self.state.name = x
  return self
end

function M:env(x)
  self.state.env = x
  return self
end

-- Adds new column to actions section of popup
---@param heading string|nil
---@return self
function M:new_action_group(heading)
  table.insert(self.state.actions, { { heading = heading or "" } })
  return self
end

-- Conditionally adds new column to actions section of popup
---@param cond boolean
---@param heading string|nil
---@return self
function M:new_action_group_if(cond, heading)
  if cond then
    return self:new_action_group(heading)
  end

  return self
end

-- Adds new heading to current column within actions section of popup
---@param heading string
---@return self
function M:group_heading(heading)
  table.insert(self.state.actions[#self.state.actions], { heading = heading })
  return self
end

-- Conditionally adds new heading to current column within actions section of popup
---@param cond boolean
---@param heading string
---@return self
function M:group_heading_if(cond, heading)
  if cond then
    return self:group_heading(heading)
  end

  return self
end

---@param key string Which key triggers switch
---@param cli string Git cli flag to use
---@param description string Description text to show user
---@param opts table|nil A table of options for the switch
---@param opts.enabled boolean Controls if the switch should default to 'on' state
---@param opts.internal boolean Whether the switch is internal to neogit or should be included in the cli command.
--                              If `true` we don't include it in the cli comand.
---@param opts.incompatible table A table of strings that represent other cli flags that this one cannot be used with
---@param opts.key_prefix string Allows overwriting the default '-' to toggle switch
---@param opts.cli_prefix string Allows overwriting the default '--' thats used to create the cli flag. Sometimes you may want
--                               to use '++' or '-'.
---@param opts.value string Allows for pre-building cli flags that can be customised by user input
---@param opts.user_input boolean If true, allows user to customise the value of the cli flag
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

  if opts.key_prefix == nil then
    opts.key_prefix = "-"
  end

  if opts.cli_prefix == nil then
    opts.cli_prefix = "--"
  end

  local value
  if opts.enabled and opts.value then
    value = cli .. opts.value
  else
    value = cli
  end

  table.insert(self.state.args, {
    type = "switch",
    id = opts.key_prefix .. key,
    key = key,
    key_prefix = opts.key_prefix,
    cli = value,
    cli_base = cli,
    description = description,
    enabled = state.get({ self.state.name, cli }, opts.enabled),
    internal = opts.internal,
    cli_prefix = opts.cli_prefix,
    user_input = opts.user_input,
    incompatible = util.build_reverse_lookup(opts.incompatible),
  })

  return self
end

-- Conditionally adds a switch.
---@see M:switch
---@param cond boolean
---@return self
function M:switch_if(cond, key, cli, description, opts)
  if cond then
    return self:switch(key, cli, description, opts)
  end

  return self
end

---@param key string Key for the user to engage option
---@param cli string CLI value used
---@param value string Current value of option
---@param description string Description of option, presented to user
---@param opts table|nil
---@param opts.key_prefix string Allows overwriting the default '=' to set option
---@param opts.cli_prefix string Allows overwriting the default '--' cli prefix
---@param opts.choices table Table of predefined choices that a user can select for option
---@param opts.default string|integer|boolean Default value for option, if the user attempts to unset value
function M:option(key, cli, value, description, opts)
  opts = opts or {}

  if opts.key_prefix == nil then
    opts.key_prefix = "="
  end

  if opts.cli_prefix == nil then
    opts.cli_prefix = "--"
  end

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
  })

  return self
end

-- Adds heading text within Arguments (options/switches) section of popup
---@param heading string Heading to show
---@return self
function M:arg_heading(heading)
  table.insert(self.state.args, { type = "heading", heading = heading })
  return self
end

---@see M:option
---@param cond boolean
---@return self
function M:option_if(cond, key, cli, value, description, opts)
  if cond then
    return self:option(key, cli, value, description, opts)
  end

  return self
end

---@param heading string Heading to render within config section of popup
---@return self
function M:config_heading(heading)
  table.insert(self.state.config, { heading = heading })
  return self
end

---@param key string Key for user to use that engages config
---@param name string Name of config
---@param options table|nil
---@param options.options table Table of tables, each consisting of `{ display = "", value = "" }`
--                              where 'display' is what is shown to the user, and 'value' is what gets used by the cli.
--                              A 'condition' key with function value can also be present in the option, which controls if the option gets shown by returning boolean.
---@param options.passive boolean Controls if this config setting can be manipulated directly, or if it is managed by git, and should just be shown in UI
---@return self
function M:config(key, name, options)
  local c = config.get(name) or { value = "" }

  local variable = {
    id = key,
    key = key,
    name = name,
    value = c.value,
    type = c.type,
  }

  for k, v in pairs(options or {}) do
    variable[k] = v
  end

  table.insert(self.state.config, variable)

  return self
end

-- Conditionally adds config to popup
---@see M:config
---@param cond boolean
---@return self
function M:config_if(cond, key, name, options)
  if cond then
    return self:config(key, name, options)
  end

  return self
end

---@param key string Key for user to hit that runs action
---@param description string Description of action in UI
---@param callback function Function that gets run in async context
---@return self
function M:action(key, description, callback)
  if not self.state.keys[key] then
    table.insert(self.state.actions[#self.state.actions], {
      key = key,
      description = description,
      callback = callback and a.void(callback) or nil,
    })

    self.state.keys[key] = true
  end

  return self
end

-- Conditionally adds action to popup
---@param cond boolean
---@see M:action
---@return self
function M:action_if(cond, key, description, callback)
  if cond then
    return self:action(key, description, callback)
  end

  return self
end

function M:build()
  if self.state.name == nil then
    error("A popup needs to have a name!")
  end

  return self.builder_fn(self.state)
end

return M
