local logger = require("neogit.logger")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")

local M = {
  history = {},
}

---@param job ProcessResult
local function store_process_result(job)
  table.insert(M.history, job)

  do
    if job.code > 0 then
      logger.trace(
        string.format(
          "[RUNNER] Execution of '%s' failed with code %d after %d ms",
          job.cmd,
          job.code,
          job.time
        )
      )

      for _, line in ipairs(job.stderr) do
        if line ~= "" then
          logger.trace(string.format("[RUNNER] [STDERR] %s", line))
        end
      end
    else
      logger.trace(string.format("[RUNNER] Execution of '%s' succeeded in %d ms", job.cmd, job.time))
    end
  end
end

---@param line string
---@return string
local function handle_interactive_authenticity(line)
  logger.debug("[RUNNER]: Confirming whether to continue with unauthenticated host")

  local prompt = line
  return input.get_user_input(
    "The authenticity of the host can't be established." .. prompt .. "",
    { cancel = "__CANCEL__" }
  ) or "__CANCEL__"
end

---@param line string
---@return string
local function handle_interactive_username(line)
  logger.debug("[RUNNER]: Asking for username")

  local prompt = line:match("(.*:?):.*")
  return input.get_user_input(prompt, { cancel = "__CANCEL__" }) or "__CANCEL__"
end

---@param line string
---@return string
local function handle_interactive_password(line)
  logger.debug("[RUNNER]: Asking for password")

  local prompt = line:match("(.*:?):.*")
  return input.get_secret_user_input(prompt, { cancel = "__CANCEL__" }) or "__CANCEL__"
end

---@param line string
---@return string
local function handle_fatal_error(line)
  logger.debug("[RUNNER]: Fatal error encountered")
  local notification = require("neogit.lib.notification")

  notification.error(line)
  return "__CANCEL__"
end
---@param process Process
---@param line string
---@return boolean
local function handle_line_interactive(process, line)
  line = util.remove_ansi_escape_codes(line)
  logger.debug(string.format("Matching interactive cmd output: '%s'", line))

  local handler
  if line:match("^Are you sure you want to continue connecting ") then
    handler = handle_interactive_authenticity
  elseif line:match("^Username for ") then
    handler = handle_interactive_username
  elseif line:match("^Enter passphrase") or line:match("^Password for") or line:match("^Enter PIN for") then
    handler = handle_interactive_password
  elseif line:match("^fatal") then
    handler = handle_fatal_error
  end

  if handler then
    process.hide_preview_buffers()

    local value = handler(line)
    if value == "__CANCEL__" then
      logger.debug("[RUNNER]: Cancelling the interactive cmd")
      process:stop()
    else
      logger.debug("[RUNNER]: Sending user input")
      process:send(value .. "\r\n")
    end

    process.defer_show_preview_buffers()
    return true
  else
    process.defer_show_preview_buffers()
    return false
  end
end

---@param process Process
---@param opts table
---@return ProcessResult
function M.call(process, opts)
  logger.trace(string.format("[RUNNER]: Executing %q", table.concat(process.cmd, " ")))

  if opts.pty then
    process.on_partial_line = function(process, line)
      if line ~= "" then
        handle_line_interactive(process, line)
      end
    end

    process.pty = true
  end

  local result
  local function run_async()
    result = process:spawn_async()
    if opts.long then
      process:stop_timer()
    end
  end

  local function run_await()
    if not process:spawn() then
      error("Failed to run command")
      return nil
    end

    result = process:wait()
  end

  if opts.await then
    logger.trace("Running command await: " .. vim.inspect(process.cmd))
    run_await()
  else
    logger.trace("Running command async: " .. vim.inspect(process.cmd))
    local ok, _ = pcall(run_async)
    if not ok then
      logger.trace("Running command async failed - awaiting instead")
      run_await()
    end
  end

  assert(result, "Command did not complete")

  result.hidden = opts.hidden
  store_process_result(result)

  if opts.trim then
    result:trim()
  end

  if opts.remove_ansi then
    result:remove_ansi()
  end

  if opts.callback then
    opts.callback()
  end

  return result
end

return M
