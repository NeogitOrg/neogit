local a = require 'plenary.async'

local M = {}

function M.new(builder_fn)
  local instance = {
    state = {
      name = nil,
      switches = {},
      options = {},
      actions = {{}},
      env = {},
    },
    builder_fn = builder_fn
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

function M:new_action_group()
  table.insert(self.state.actions, {})
  return self
end

function M:switch(key, cli, description, enabled, parse)
  if enabled == nil then
    enabled = false
  end

  if parse == nil then
    parse = true
  end

  table.insert(self.state.switches, {
    id = '-' .. key,
    key = key,
    cli = cli,
    description = description,
    enabled = enabled,
    parse = parse
  })

  return self
end

function M:option(key, cli, value, description)
  table.insert(self.state.options, {
    id = '=' .. key,
    key = key,
    cli = cli,
    value = value,
    description = description,
  })

  return self
end

function M:action(key, description, callback)
  table.insert(self.state.actions[#self.state.actions], {
    key = key,
    description = description,
    callback = callback and a.void(callback) or nil
  })

  return self
end

function M:action_if(cond, key, description, callback)
  if cond then
    table.insert(self.state.actions[#self.state.actions], {
      key = key,
      description = description,
      callback = callback and a.void(callback) or nil
    })
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
