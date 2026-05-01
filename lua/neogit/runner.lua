local logger = require("neogit.logger")
local input = require("neogit.lib.input")
local util = require("neogit.lib.util")
local notification = require("neogit.lib.notification")

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
  return input.get_user_input_blocking(
    "The authenticity of the host can't be established." .. prompt .. "",
    { cancel = "__CANCEL__" }
  ) or "__CANCEL__"
end

---@param line string
---@return string
local function handle_interactive_username(line)
  logger.debug("[RUNNER]: Asking for username")

  local prompt = line:match("(.*:?):.*")
  return input.get_user_input_blocking(prompt, { cancel = "__CANCEL__" }) or "__CANCEL__"
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
---@param state table
---@return boolean
local function handle_line_interactive(process, line, state)
  line = util.remove_ansi_escape_codes(line)
  logger.debug(string.format("Matching interactive cmd output: '%s'", line))

  local handler
  local cacheable = false
  if line:match("^Are you sure you want to continue connecting ") then
    handler = handle_interactive_authenticity
    cacheable = true
  elseif line:match("^Username for ") then
    handler = handle_interactive_username
    cacheable = true
  elseif line:match("^Enter passphrase") or line:match("^Password for") or line:match("^Enter PIN for") then
    state.password_attempts = (state.password_attempts or 0) + 1
    handler = handle_interactive_password
  elseif line:match("^fatal") then
    handler = handle_fatal_error
  end

  if handler then
    process.hide_preview_buffers()

    local value
    if cacheable and state.cached_responses[line] then
      logger.debug("[RUNNER]: Replaying cached response for: " .. line)
      value = state.cached_responses[line]
    else
      value = handler(line)
      if cacheable and value ~= "__CANCEL__" then
        state.cached_responses[line] = value
      end
    end

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

  local MAX_PASSWORD_ATTEMPTS = 3
  local state = { password_attempts = 0, cached_responses = {} }

  local function setup_pty(proc)
    if opts.pty then
      proc.on_partial_line = function(p, line)
        if line ~= "" then
          handle_line_interactive(p, line, state)
        end
      end
      proc.pty = true
    end
  end

  local function run(proc)
    local result
    local function run_async()
      result = proc:spawn_async()
      if opts.long then
        proc:stop_timer()
      end
    end

    local function run_await()
      if not proc:spawn() then
        error("Failed to run command")
        return nil
      end
      result = proc:wait()
    end

    if opts.await then
      logger.trace("Running command await: " .. vim.inspect(proc.cmd))
      run_await()
    else
      logger.trace("Running command async: " .. vim.inspect(proc.cmd))
      local ok, _ = pcall(run_async)
      if not ok then
        logger.trace("Running command async failed - awaiting instead")
        run_await()
      end
    end

    return result
  end

  setup_pty(process)
  local result = run(process)
  assert(result, "Command did not complete")
  store_process_result(result)

  while
    result.code ~= 0
    and state.password_attempts > 0
    and state.password_attempts < MAX_PASSWORD_ATTEMPTS
  do
    logger.debug(
      string.format(
        "[RUNNER]: Retrying after failed auth (attempt %d/%d)",
        state.password_attempts,
        MAX_PASSWORD_ATTEMPTS
      )
    )
    notification.warn("Authentication Failed")
    local retry = process:clone()
    if opts.on_retry then
      opts.on_retry(retry)
    end
    setup_pty(retry)
    result = run(retry)
    assert(result, "Command did not complete")
    store_process_result(result)
  end

  if result.code ~= 0 and state.password_attempts >= MAX_PASSWORD_ATTEMPTS then
    notification.error("Authentication failed after " .. MAX_PASSWORD_ATTEMPTS .. " attempts")
  end

  result.hidden = opts.hidden

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
