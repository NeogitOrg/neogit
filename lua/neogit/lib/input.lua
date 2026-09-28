local a = require("neogit.lib.async")

-- `vim.ui.input`, hardened against implementations that close their prompt
-- without ever invoking the callback.
--
-- The built-in cmdline input always calls back, but several floating-window
-- replacements (e.g. snacks.nvim) only call `on_confirm` via their own
-- confirm/cancel actions and skip it entirely when the window is dismissed
-- some other way (`:q`, `<C-w>c`, a focus steal, a programmatic close). A
-- dropped callback parks the awaiting coroutine forever -- and because popup
-- actions run under a single shared permit lock, one parked action silently
-- turns *every* subsequent popup action into a no-op until Neovim restarts.
--
-- We guarantee the callback fires exactly once: the real value if the user
-- responds, or `nil` (a normal cancel) if the prompt window closes first.
local input = a.wrap(function(opts, callback)
  local done = false
  local function finish(value)
    if done then
      return
    end
    done = true
    callback(value)
  end

  vim.ui.input(opts, finish)

  -- If the implementation synchronously entered a floating prompt window,
  -- treat that window closing without a result as a cancel. Deferred so a
  -- real callback dispatched during the same close wins the race: both the
  -- value and this fallback get scheduled, and implementations call
  -- `on_confirm` before closing, so the real value is enqueued first.
  local win = vim.api.nvim_get_current_win()
  if not done and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = tostring(win),
      once = true,
      callback = function()
        vim.schedule(function()
          finish(nil)
        end)
      end,
    })
  end
end, 2)

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

--- Provides the user with a confirmation. Like get_confirmation, but defaults to false
---@param msg string Prompt to use for confirmation
---@param options table|nil
---@return boolean Confirmation (Yes/No)
function M.get_permission(msg, options)
  options = options or {}
  options.values = options.values or { "&Yes", "&No" }
  options.default = options.default or 2

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
  vim.cmd("redraw")

  if choice == 0 then -- User cancelled
    choice = options.default
  end

  return options.values[choice]:match("&(.)")
end

---@class GetUserInputOpts
---@field strip_spaces boolean? Replace spaces with dashes
---@field default any? Default value
---@field completion string?
---@field separator string?
---@field cancel string?
---@field prepend string?

---@param prompt string Prompt to use for user input
---@param opts GetUserInputOpts? Options table
---@return string|nil
function M.get_user_input(prompt, opts)
  opts = vim.tbl_extend("keep", opts or {}, { strip_spaces = false, separator = ": " })

  if opts.prepend then
    vim.defer_fn(function()
      vim.api.nvim_input(opts.prepend)
    end, 10)
  end

  local status, result = pcall(input, {
    prompt = ("%s%s"):format(prompt, opts.separator),
    default = opts.default,
    completion = opts.completion,
    cancelreturn = opts.cancel,
  })

  if not status or not result then
    return nil
  end

  if opts.strip_spaces then
    result, _ = result:gsub("%s", "-")
  end

  if result == "" then
    return nil
  end

  return result
end

---Blocking variant to get user input. Needed for usernames/passwords during git interactions
---@param prompt string Prompt to use for user input
---@param opts GetUserInputOpts? Options table
---@return string|nil
function M.get_user_input_blocking(prompt, opts)
  opts = vim.tbl_extend("keep", opts or {}, { strip_spaces = false, separator = ": " })

  vim.fn.inputsave()

  if opts.prepend then
    vim.defer_fn(function()
      vim.api.nvim_input(opts.prepend)
    end, 10)
  end

  local status, result = pcall(vim.fn.input, {
    prompt = ("%s%s"):format(prompt, opts.separator),
    default = opts.default,
    completion = opts.completion,
    cancelreturn = opts.cancel,
  })

  vim.fn.inputrestore()
  if not status then
    return nil
  end

  if result == nil then
    return nil
  end

  if opts.strip_spaces then
    result, _ = result:gsub("%s", "-")
  end

  if result == "" then
    return nil
  end

  return result
end

---@param prompt string
---@param opts? table
---@return string|nil
function M.get_secret_user_input(prompt, opts)
  opts = vim.tbl_extend("keep", opts or {}, { separator = ": " })

  vim.fn.inputsave()
  local status, result = pcall(vim.fn.inputsecret, {
    prompt = ("%s%s"):format(prompt, opts.separator),
    cancelreturn = opts.cancel,
  })

  vim.fn.inputrestore()
  if not status then
    return nil
  end

  return result
end

return M
