local a = require("plenary.async")

local Buffer = require("neogit.lib.buffer")

local function remove_escape_codes(s)
  -- from: https://stackoverflow.com/questions/48948630/lua-ansi-escapes-pattern

  return s:gsub("[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]", ""):gsub("[\r\n]", "")
end

---@class Process
---@field cmd string[]
---@field cwd string|nil
---@field env table<string, string>|nil
---@field verbose boolean If true, stdout will be written to the console buffer
---@field input string|string[]|nil
---@field result ProcessResult|nil
local Process = {}
Process.__index = Process

---@type { number: Process }
local processes = {}

---@class ProcessResult
---@field stdout string[]
---@field stderr string[]
---@field code number
---@field time number seconds

---@param process Process
---@return Process
function Process.new(process)
  return setmetatable(process, Process)
end

local preview_buffer = nil

local function create_preview_buffer()
  -- May be called multiple times due to scheduling
  if preview_buffer then
    return
  end

  local name = "Neogit log"
  local cur = vim.fn.bufnr(name)
  if cur and cur ~= -1 then
    vim.api.nvim_buf_delete(cur, { force = true })
  end

  local buffer = Buffer.create {
    name = name,
    bufhidden = "hide",
    filetype = "terminal",
    kind = "split",
    open = false,
    mappings = {
      n = {
        ["q"] = function(buffer)
          buffer:close(true)
        end,
      },
    },
    autocmds = {
      ["BufUnload"] = function()
        preview_buffer = nil
      end,
    },
  }

  local chan = vim.api.nvim_open_term(buffer.handle, {})

  preview_buffer = {
    chan = chan,
    buffer = buffer,
    current_span = nil,
  }
end

local function show_preview_buffer()
  if not preview_buffer then
    create_preview_buffer()
  end

  preview_buffer.buffer:show()
  -- vim.api.nvim_win_call(win, function()
  --   vim.cmd("normal! G")
  -- end)
end

local nvim_chan_send = vim.api.nvim_chan_send

---@param process Process
---@param data string
local function append_log(process, data)
  local function append()
    if preview_buffer.current_span ~= process.job then
      nvim_chan_send(preview_buffer.chan, string.format("\r\n> %s\r\n", table.concat(process.cmd, " ")))
      preview_buffer.current_span = process.job
    end

    -- Explicitly reset indent
    -- https://github.com/neovim/neovim/issues/14557
    data = data:gsub("\n", "\r\n")
    nvim_chan_send(preview_buffer.chan, data)
  end

  if not preview_buffer then
    vim.schedule(function()
      create_preview_buffer()
      append()
    end)
  else
    append()
  end
end

local hide_console = false
function Process.hide_preview_buffers()
  hide_console = true
  --- Stop all times from opening the buffer
  for _, v in pairs(processes) do
    v:stop_timer()
  end

  if preview_buffer then
    preview_buffer.buffer:hide()
  end
end

local config = require("neogit.config")
function Process:start_timer()
  if self.timer == nil then
    local timer = vim.loop.new_timer()
    timer:start(
      config.values.console_timeout,
      0,
      vim.schedule_wrap(function()
        self.timer = nil
        timer:stop()
        timer:close()
        if not self.result or self.result.code ~= 0 then
          append_log(
            self,
            string.format("Command running for: %.2f ms", (vim.loop.hrtime() - self.start) / 1e6)
          )
          show_preview_buffer()
        end
      end)
    )
    self.timer = timer
  end
end

function Process:stop_timer()
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
end

function Process.defer_show_preview_buffers()
  hide_console = false
  --- Start the timers again, making all proceses show the log buffer on a long
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

--- Spawn and await the process
--- Must be called inside a plenary async context
---
--- Returns nil if spawning fails
---@return ProcessResult|nil
function Process:spawn_async()
  return a.wrap(Process.spawn, 2)(self)
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
---@param cb fun(ProcessResult)|nil
---@return boolean success
function Process:spawn(cb)
  ---@type ProcessResult
  local res = {
    stdout = { "" },
    stderr = { "" },
  }

  assert(self.job == nil, "Process started twice")
  -- An empty table is treated as an array
  self.env = self.env or {}
  self.env.TERM = "xterm-256color"
  if self.cwd == "<current>" then
    self.cwd = nil
  end

  local start = vim.loop.hrtime()
  self.start = start

  local function on_stdout(_, data)
    local d = remove_escape_codes(data[1])
    res.stdout[#res.stdout] = res.stdout[#res.stdout] .. d

    for i = 2, #data do
      d = remove_escape_codes(data[i])

      table.insert(res.stdout, d)
    end

    if self.verbose then
      append_log(self, table.concat(data))
    end
  end

  local function on_stderr(_, data)
    local d = remove_escape_codes(data[1])
    res.stderr[#res.stderr] = res.stderr[#res.stderr] .. d

    for i = 2, #data do
      d = remove_escape_codes(data[i])
      table.insert(res.stderr, d)
    end

    append_log(self, table.concat(data))
  end

  local function on_exit(_, code)
    res.stdout = vim.tbl_filter(function(v)
      return v ~= ""
    end, res.stdout)

    res.stderr = vim.tbl_filter(function(v)
      return v ~= ""
    end, res.stderr)

    res.code = code
    res.time = (vim.loop.hrtime() - start) / 1e6

    -- Remove self
    processes[self.job] = nil
    self.result = res
    self:stop_timer()

    if self.verbose and code ~= 0 and not hide_console then
      vim.schedule(show_preview_buffer)
    end

    if cb then
      cb(res)
    end
  end

  local job = vim.fn.jobstart(self.cmd, {
    cwd = self.cwd,
    env = self.env,
    -- Fake a small standard terminal
    pty = true,
    width = 80,
    height = 24,
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = on_exit,
  })

  if job <= 0 then
    error("Failed to start process: ", vim.inspect(self))
    if cb then
      cb(nil)
    end
    return false
  end

  processes[job] = self
  self.job = job

  if not hide_console then
    self:start_timer()
  end

  if self.input ~= nil then
    if type(self.input) == "string" then
      vim.api.nvim_chan_send(job, self.input)
    elseif type(self.input) == "table" then
      vim.api.nvim_chan_send(job, table.concat(self.input, "\r\n"))
    else
      error("Input must be either nil, string or string{}")
    end
  end

  -- Send eof
  vim.api.nvim_chan_send(job, "\04")
  vim.fn.chanclose(job, "stdin")

  return true
end

return Process
