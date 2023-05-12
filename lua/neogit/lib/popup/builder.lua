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

function M:new_action_group(heading)
  table.insert(self.state.actions, { { heading = heading or "" } })
  return self
end

function M:new_action_group_if(cond, heading)
  if cond then
    return self:new_action_group(heading)
  end

  return self
end

function M:group_heading(heading)
  table.insert(self.state.actions[#self.state.actions], { heading = heading })
  return self
end

function M:group_heading_if(cond, heading)
  if cond then
    return self:group_heading(heading)
  end

  return self
end

---@param opts.internal boolean Whether the switch is internal to neogit or should be included in the cli command.
--                              If `true` we don't include it in the cli comand.
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

function M:switch_if(cond, key, cli, description, opts)
  if cond then
    return self:switch(key, cli, description, opts)
  end

  return self
end

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

function M:arg_heading(heading)
  table.insert(self.state.args, { type = "heading", heading = heading })
  return self
end

function M:option_if(cond, key, cli, value, description, opts)
  if cond then
    return self:option(key, cli, value, description, opts)
  end

  return self
end

function M:config_heading(heading)
  table.insert(self.state.config, { heading = heading })
  return self
end

function M:config(key, name, options)
  local c = config.get(name)
  if c.value == nil then
    c.value = ""
  end

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

function M:config_if(cond, key, name, options)
  if cond then
    return self:config(key, name, options)
  end

  return self
end

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
