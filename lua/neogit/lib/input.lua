local M = {}

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

---@param prompt string Prompt to use for user input
---@param default any Default value to use
---@param completion string? Completion type to use. See vim docs for :command-complete
---@return string|nil
function M.get_user_input(prompt, default, completion)
  vim.fn.inputsave()

  local status, result = pcall(vim.fn.input, {
    prompt = prompt,
    default = default,
    completion = completion,
  })

  vim.fn.inputrestore()
  if not status then
    return nil
  end

  return result
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

return M
