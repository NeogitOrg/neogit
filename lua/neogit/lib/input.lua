local M = {}

-- selene: allow(global_usage)
if not _G.__NEOGIT then
  _G.__NEOGIT = {}
end

-- selene: allow(global_usage)
if not _G.__NEOGIT.completers then
  _G.__NEOGIT.completers = {}
end

local function user_input_prompt(prompt, default_value, completion_function)
  vim.fn.inputsave()

  local status, result = pcall(vim.fn.input, {
    prompt = prompt,
    default = default_value,
    completion = completion_function and ("customlist,v:lua.__NEOGIT.completers." .. completion_function)
      or nil,
  })

  vim.fn.inputrestore()
  if not status then
    return nil
  end
  return result
end

local COMPLETER_SEQ = 1
local function make_completion_function(options)
  local id = "completer" .. tostring(COMPLETER_SEQ)
  COMPLETER_SEQ = COMPLETER_SEQ + 1

  -- selene: allow(global_usage)
  _G.__NEOGIT.completers[id] = function(arg_lead)
    local result = {}
    for _, v in ipairs(options) do
      if v:lower():find(arg_lead:lower(), nil, true) then
        table.insert(result, v)
      end
    end
    return result
  end

  return id
end

-- selene: allow(global_usage)
local function remove_completion_function(id)
  _G.__NEOGIT.completers[id] = nil
end

--- Provides the user with a confirmation
---@param msg string Prompt to use for confirmation
---@param options table|nil
---@return boolean Confirmation (Yes/No)
function M.get_confirmation(msg, options)
  options = options or {}
  options.values = options.values or { "&Yes", "&No" }
  options.default = options.default or 1

  return vim.fn.confirm(msg, table.concat(options.values, "\n"), options.default) == 1
end

---@class UserChoiceOptions
---@field values table List of choices prefixed with '&'
---@field default integer Default choice to select

--- Provides the user with choices
---@param msg string Prompt to use for the choices
---@param options UserChoiceOptions
---@return string First letter of the selected choice
function M.get_choice(msg, options)
  local choice = vim.fn.confirm(msg, table.concat(options.values, "\n"), options.default)
  return options.values[choice]:match("&(.)")
end

function M.get_user_input(prompt, default)
  return user_input_prompt(prompt, default)
end

function M.get_secret_user_input(prompt)
  vim.fn.inputsave()

  local status, result = pcall(vim.fn.inputsecret, prompt)

  vim.fn.inputrestore()

  if not status then
    return nil
  end

  return result
end

function M.get_user_input_with_completion(prompt, options)
  local completer_id = make_completion_function(options)
  local result = user_input_prompt(prompt, nil, completer_id)
  remove_completion_function(completer_id)
  return result
end

return M
