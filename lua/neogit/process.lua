local a = require("plenary.async")
local notification = require("neogit.lib.notification")

local config = require("neogit.config")
local logger = require("neogit.logger")

-- from: https://stackoverflow.com/questions/48948630/lua-ansi-escapes-pattern
local pattern_1 = "[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]"
local pattern_2 = "[\r\n\04\08]"
local function remove_escape_codes(s)
  return s:gsub(pattern_1, ""):gsub(pattern_2, "")
end

local command_mask =
  vim.pesc(" --no-pager --literal-pathspecs --no-optional-locks -c core.preloadindex=true -c color.ui=always")

local function mask_command(cmd)
  local command, _ = cmd:gsub(command_mask, "")
  return command
end

---@class Process
---@field cmd string[]
---@field cwd string|nil
---@field env table<string, string>|nil
---@field verbose boolean If true, stdout will be written to the console buffer
---@field result ProcessResult|nil
---@field job number|nil
---@field stdin number|nil
---@field pty boolean|nil
---@field buffer ProcessBuffer
---@field on_partial_line fun(process: Process, data: string, raw: string)|nil callback on complete lines
---@field on_error (fun(res: ProcessResult): boolean) Intercept the error externally, returning false prevents the error from being logged
local Process = {}
Process.__index = Process

---@type { number: Process }
local processes = {}
setmetatable(processes, { __mode = "k" })

---@class ProcessResult
---@field stdout string[]
---@field stdout_raw string[]
---@field stderr string[]
---@field output string[]
---@field code number
---@field time number seconds
local ProcessResult = {}

---Removes empty lines from output
---@return ProcessResult
function ProcessResult:trim()
  self.stdout = vim.tbl_filter(function(v)
    return v ~= ""
  end, self.stdout)

  self.stderr = vim.tbl_filter(function(v)
    return v ~= ""
  end, self.stderr)

  return self
end
ProcessResult.__index = ProcessResult

---@param process Process
---@return Process
function Process.new(process)
  process.buffer = require("neogit.buffers.process"):new(process)
  return setmetatable(process, Process)
end

local hide_console = false
function Process.hide_preview_buffers()
  hide_console = true

  --- Stop all times from opening the buffer
  for _, v in pairs(processes) do
    v:stop_timer()
  end
end

function Process:start_timer()
  if self.timer == nil then
    local timer = vim.loop.new_timer()
    self.timer = timer

    timer:start(
      config.values.console_timeout,
      0,
      vim.schedule_wrap(function()
        if not self.timer then
          return
        end

        self:stop_timer()

        if not self.result or (self.result.code ~= 0) then
          local message = string.format(
            "Command %q running for more than: %.1f seconds",
            mask_command(table.concat(self.cmd, " ")),
            math.ceil((vim.loop.now() - self.start) / 100) / 10
          )

          self.buffer:append(message)

          if config.values.auto_show_console then
            self.buffer:show()
          else
            notification.warn(message .. "\n\nOpen the console for details")
          end
        end
      end)
    )
  end
end

function Process:stop_timer()
  if self.timer then
    local timer = self.timer
    self.timer = nil
    timer:stop()

    if not timer:is_closing() then
      timer:close()
    end
  end
end

function Process.defer_show_preview_buffers()
  hide_console = false
  --- Start the timers again, making all processes show the log buffer on a long
  --- running command
  for _, v in pairs(processes) do
    v:start_timer()
  end
end

--- Blocks until process completes
---@param timeout number|nil
---@return ProcessResult|nil
function Process:wait(timeout)
  if not self.job then
    error("Process not started")
  end
  if timeout then
    vim.fn.jobwait({ self.job }, timeout)
  else
    vim.fn.jobwait { self.job }
  end

  return self.result
end

function Process:stop()
  if self.job then
    vim.fn.jobstop(self.job)
  end
end

--- Spawn and await the process
--- Must be called inside a plenary async context
---
--- Returns nil if spawning fails
---@param post fun(process: Process)|nil
---@return ProcessResult|nil
function Process:spawn_async(post)
  return a.wrap(function(cb)
    self:spawn(cb)
    if post then
      post(self)
    end
  end, 1)()
end

--- Spawn and block until the process completes
--- If timeout is not nil and the process does not complete in time, nil is
--- returned
---@return ProcessResult|nil
function Process:spawn_blocking(timeout)
  self:spawn()
  return self:wait(timeout)
end

---Spawns a process in the background and returns immediately
---@param cb fun(result: ProcessResult|nil)|nil
---@return boolean success
function Process:spawn(cb)
  ---@type ProcessResult
  local res = setmetatable({
    stdout = {},
    stdout_raw = {},
    stderr = {},
    output = {},
  }, ProcessResult)

  assert(self.job == nil, "Process started twice")

  self.env = self.env or {}
  self.env.TERM = "xterm-256color"

  local start = vim.loop.now()
  self.start = start

  local function handle_output(on_partial, on_line)
    local prev_line = ""

    return function(_, lines)
      -- Complete previous line
      prev_line = prev_line .. lines[1]

      on_partial(remove_escape_codes(lines[1]), lines[1])

      for i = 2, #lines do
        on_line(remove_escape_codes(prev_line), prev_line)
        prev_line = ""
        -- Before pushing a new line, invoke the stdout for components
        prev_line = lines[i]
        on_partial(remove_escape_codes(lines[i]), lines[i])
      end
    end, function()
      on_line(remove_escape_codes(prev_line), prev_line)
    end
  end

  local on_stdout, stdout_cleanup = handle_output(function(line, raw)
    if self.on_partial_line then
      self.on_partial_line(self, line, raw)
    end
  end, function(line, raw)
    table.insert(res.stdout, line)
    table.insert(res.stdout_raw, raw)
    if self.verbose then
      table.insert(res.output, line)
      self.buffer:append(raw)
    end
  end)

  local on_stderr, stderr_cleanup = handle_output(function() end, function(line, raw)
    table.insert(res.stderr, line)
    table.insert(res.output, line)
    self.buffer:append(raw)
  end)

  local function on_exit(_, code)
    res.code = code
    res.time = (vim.loop.now() - start)

    -- Remove self
    processes[self.job] = nil
    self.result = res
    self:stop_timer()

    stdout_cleanup()
    stderr_cleanup()

    self.buffer:append(string.format("Process exited with code: %d", code))

    if not self.buffer:is_visible() and code > 0 and self.on_error(res) then
      local output = {}
      local start = math.max(#res.output - 16, 1)
      for i = start, math.min(#res.output, start + 16) do
        table.insert(output, "    " .. res.output[i])
      end

      local message = string.format(
        "%s:\n\n%s\n\nAn error occurred.",
        mask_command(table.concat(self.cmd, " ")),
        table.concat(output, "\n")
      )

      notification.warn(message)
    end

    self.stdin = nil
    self.job = nil

    if cb then
      cb(res)
    end
  end

  logger.trace("[PROCESS] Spawning: " .. vim.inspect(self.cmd))
  local job = vim.fn.jobstart(self.cmd, {
    cwd = self.cwd,
    env = self.env,
    pty = not not self.pty,
    width = 80,
    height = 24,
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = on_exit,
  })

  if job <= 0 then
    error("Failed to start process: " .. vim.inspect(self))
    if cb then
      cb(nil)
    end
    return false
  end

  processes[job] = self
  self.job = job
  self.stdin = job

  if not hide_console then
    self:start_timer()
  end

  return true
end

function Process:close_stdin()
  -- Send eof
  if self.stdin then
    self.stdin = nil
    vim.fn.chanclose(self.job, "stdin")
  end
end

--- Send input to the running process
---@param data string
function Process:send(data)
  if self.stdin then
    assert(type(data) == "string", "Data must be of type string")
    vim.api.nvim_chan_send(self.job, data)
  end
end

return Process
