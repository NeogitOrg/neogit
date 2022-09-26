local a = require("plenary.async")

local Buffer = require("neogit.lib.buffer")
local function trim_newlines(s)
  return (string.gsub(s, "^(.-)\n*$", "%1"))
end

local M = {}

---@class Process
---@field cmd string
---@field handle number
---@field code number|nil
---@field buffer Buffer|nil
---@field chan number|nil
---@field silent boolean
local Process = {}
Process.__index = Process

---@type { number: Process }
local processes = {}

---@param cmd string
---@return Process
function Process:new(cmd)
  return setmetatable({ cmd = cmd }, self)
end

function Process:close_buffer()
  if self.buffer then
    self.buffer:close(true)
    self.buffer = nil
  end
end

local preview_buffer = nil

local function create_preview_buffer()
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

  -- Jump to end

  local win = preview_buffer.buffer:show()
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! G")
  end)
end

local nvim_chan_send = vim.api.nvim_chan_send

---@param process Process
---@param data string
local function append_log(process, data)
  if not preview_buffer then
    create_preview_buffer()
  end

  if preview_buffer.current_span ~= process.handle then
    nvim_chan_send(preview_buffer.chan, string.format("> %s\r\n", process.cmd))
    preview_buffer.current_span = process.handle
  end

  data = data:gsub("\n", "\r\n")
  -- Explicitly reset indent
  -- https://github.com/neovim/neovim/issues/14557
  nvim_chan_send(preview_buffer.chan, data)
end

function M.hide_preview_buffers()
  --- Stop all times from opening the buffer
  for _, v in pairs(processes) do
    v:stop_timer()
  end

  if preview_buffer then
    preview_buffer.buffer:hide()
  end
end

function Process:start_timer()
  if self.timer == nil then
    local timer = vim.loop.new_timer()
    timer:start(
      1000,
      0,
      vim.schedule_wrap(function()
        if self.code ~= 0 then
          show_preview_buffer()
        end
        self.timer = nil
        timer:stop()
        timer:close()
      end)
    )
  end
end

function Process:stop_timer()
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
end
function M.defer_show_preview_buffers()
  --- Start the timers again, making all proceses show the log buffer on a long
  --- running command
  for _, v in pairs(processes) do
    v:start_timer()
  end
end

local function spawn(options, cb)
  assert(options ~= nil, "Options parameter must be given")
  assert(options.cmd, "A command needs to be given!")

  local return_code, output, errors = nil, "", ""
  local stdin, stdout, stderr = vim.loop.new_pipe(false), vim.loop.new_pipe(false), vim.loop.new_pipe(false)
  local process_closed, stdout_closed, stderr_closed = false, false, false
  local function raise_if_fully_closed()
    if process_closed and stdout_closed and stderr_closed then
      cb(trim_newlines(output), return_code, trim_newlines(errors))
    end
  end

  local params = {
    stdio = { stdin, stdout, stderr },
  }

  if options.cwd then
    params.cwd = options.cwd
  end
  if options.args then
    params.args = options.args
  end
  if options.env then
    params.env = {}
    -- setting 'env' completely overrides the parent environment, so we need to
    -- append all variables that are necessary for git to work in addition to
    -- all variables from passed object.
    table.insert(params.env, string.format("%s=%s", "HOME", os.getenv("HOME")))
    table.insert(params.env, string.format("%s=%s", "GNUPGHOME", os.getenv("GNUPGHOME") or ""))
    table.insert(params.env, string.format("%s=%s", "NVIM", vim.v.servername))
    table.insert(params.env, string.format("%s=%s", "PATH", os.getenv("PATH")))
    table.insert(params.env, string.format("%s=%s", "SSH_AUTH_SOCK", os.getenv("SSH_AUTH_SOCK") or ""))
    table.insert(params.env, string.format("%s=%s", "SSH_AGENT_PID", os.getenv("SSH_AGENT_PID") or ""))
    for k, v in pairs(options.env) do
      table.insert(params.env, string.format("%s=%s", k, v))
    end
  end

  local handle, err
  local process = Process:new(options.cmd .. " " .. table.concat(params.args, " "))
  process.silent = options.silent or false

  handle, err = vim.loop.spawn(options.cmd, params, function(code, _)
    handle:close()
    --print('finished process', vim.inspect(params), vim.inspect({trim_newlines(output), errors}))

    return_code = code
    process.code = code
    vim.schedule(function()
      -- Remove process
      processes[process.handle] = nil
      if code ~= 0 then
        show_preview_buffer()
      end
    end)
    process_closed = true
    raise_if_fully_closed()
  end)
  --print('started process', vim.inspect(params), '->', handle, err, '@'..(params.cwd or '')..'@', options.input)
  if not handle then
    stdout:close()
    stderr:close()
    stdin:close()
    error(err)
  end

  process.handle = handle
  processes[handle] = process

  vim.loop.read_start(stdout, function(err, data)
    assert(not err, err)
    if not data then
      stdout:read_stop()
      stdout:close()
      stdout_closed = true
      raise_if_fully_closed()
      return
    end

    --print('STDOUT', err, data)
    output = output .. data
    vim.schedule(function()
      append_log(process, data)
    end)
  end)

  vim.loop.read_start(stderr, function(err, data)
    assert(not err, err)
    if not data then
      stderr:read_stop()
      stderr:close()
      stderr_closed = true
      raise_if_fully_closed()
      return
    end

    --print('STDERR', err, data)
    errors = errors .. (data or "")
    vim.schedule(function()
      append_log(process, data)
    end)
  end)

  local timer = vim.loop.new_timer()
  process.timer = timer
  timer:start(
    1000,
    0,
    vim.schedule_wrap(function()
      -- When the process has been running for too long, show the log buffer
      if not process.silent and process.code ~= 0 then
        vim.notify("Creating buffer")
        show_preview_buffer()
      end
      process.timer = nil
      timer:stop()
      timer:close()
    end)
  )

  if options.input ~= nil then
    vim.loop.write(stdin, options.input)
  end

  stdin:close()
end

M.spawn = a.wrap(spawn, 2)
M.spawn_sync = spawn

return M
