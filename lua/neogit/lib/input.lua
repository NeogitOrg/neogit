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

  local args = {
    prompt = prompt
  }
  if default_value then 
    args.default = default_value 
  end
  if completion_function then 
    args.completion = 'customlist,v:lua.__NEOGIT.completers.'..completion_function 
  end

  local status, result = pcall(vim.fn.input, args)

  vim.fn.inputrestore()
  if not status then return nil end
  return result
end

local COMPLETER_SEQ = 1
local function make_completion_function(options)
  local id = 'completer'..tostring(COMPLETER_SEQ)
  COMPLETER_SEQ = COMPLETER_SEQ + 1

  -- selene: allow(global_usage)
  _G.__NEOGIT.completers[id] = function (arg_lead)
    local result = {}
    for _, v in ipairs(options) do
      if v:match(arg_lead) then
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

function M.get_confirmation(msg, options)
  options = options or {}
  options.values = options.values or { "&Yes", "&No" }
  options.default = options.default or 1

  return vim.fn.confirm(msg, table.concat(options.values, "\n"), options.default) == 1
end

function M.get_user_input(prompt)
  return user_input_prompt(prompt)
end

function M.get_secret_user_input(prompt)
  vim.fn.inputsave()

  local status, result = pcall(vim.fn.inputsecret, prompt)

  vim.fn.inputrestore()

  if not status then return nil end

  return result
end

function M.get_user_input_with_completion(prompt, options)
  local completer_id = make_completion_function(options)
  local result = user_input_prompt(prompt, nil, completer_id)
  remove_completion_function(completer_id)
  return result
end

return M
