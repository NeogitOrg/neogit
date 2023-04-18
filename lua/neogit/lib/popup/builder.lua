local a = require("plenary.async")
local state = require("neogit.lib.state")
local config = require("neogit.lib.git.config")
local util = require("neogit.lib.util")

local M = {}

function M.new(builder_fn)
  local instance = {
    state = {
      name = nil,
      switches = {},
      options = {},
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
    table.insert(self.state.actions, { { heading = heading or "" } })
  end

  return self
end

function M:group_heading(heading)
  table.insert(self.state.actions[#self.state.actions], { heading = heading })
  return self
end

function M:group_heading_if(cond, heading)
  if cond then
    table.insert(self.state.actions[#self.state.actions], { heading = heading })
  end

  return self
end

---@param opts.parse boolean Whether the switch is internal to neogit or should be included in the cli command.
--                           If `false` we don't include it in the cli comand.
function M:switch(key, cli, description, opts)
  opts = opts or {}

  if opts.enabled == nil then
    opts.enabled = false
  end

  if opts.parse == nil then
    opts.parse = true
  end

  if opts.incompatible == nil then
    opts.incompatible = {}
  end

  table.insert(self.state.switches, {
    id = "-" .. key,
    key = key,
    cli = cli,
    description = description,
    enabled = state.get({ self.state.name, cli }, opts.enabled),
    parse = opts.parse,
    cli_prefix = opts.cli_prefix or "--",
    incompatible = util.build_reverse_lookup(opts.incompatible),
  })

  return self
end

function M:option(key, cli, value, description, opts)
  opts = opts or {}

  table.insert(self.state.options, {
    id = "=" .. key,
    key = key,
    cli = cli,
    value = state.get({ self.state.name, cli }, value),
    description = description,
    cli_prefix = opts.cli_prefix or "--",
    choices = opts.choices,
  })

  return self
end

function M:config_heading(heading)
  table.insert(self.state.config, { heading = heading })
  return self
end

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
  if cond and not self.state.keys[key] then
    table.insert(self.state.actions[#self.state.actions], {
      key = key,
      description = description,
      callback = callback and a.void(callback) or nil,
    })

    self.state.keys[key] = true
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
