package.loaded["neogit.lib.job"] = nil

local util = require("neogit.lib.util")

local Job = {
  cmd = nil,
  channel = nil,
  stdout = {},
  stderr = {},
  time = 0,
  code = 0,
  running = false,
  done = false,
  on_stdout = nil,
  on_stderr = nil,
  on_exit = nil
}

local is_win = vim.fn.has('win32') == 1 

--- Creates a new Job
--@tparam string cmd the command to be executed
--@tparam function? on_exit a callback that gets called when the job exits
function Job.new(options)
  assert(options.cmd, "A job needs to have a cmd")

  setmetatable(options, { __index = Job })

  return options
end

--- Starts the job
function Job:start()
  if not self.cmd and not self.running and not self.done then
    return
  end

  self.done = false
  self.running = true
  self.stdout = {}
  self.stderr = {}
  local started_at = os.clock()

  local task = self.cmd

  if type(task) == "string"
    and is_win 
    then
    task = task:gsub("%^", "%^%^")
    task = { 'cmd', '/C', task }
  end

  local stdout_line_buffer = ""
  local stderr_line_buffer = ""

  self.channel = vim.fn.jobstart(task, {
    cwd = self.cwd,
    on_exit = function(_, code)
      self.code = code
      self.done = true
      self.running = false
      self.time = (os.clock() - started_at) * 1000

      if type(self.on_exit) == "function" then
        self.on_exit(self)
      end
    end,
    on_stdout = function(_, data)
      data[1] = stdout_line_buffer .. data[1]

      for i=1,#data-1 do
        local data = data[i]:gsub("\r", "")
        if type(self.on_stdout) == "function" then
          self.on_stdout(data)
        end
        table.insert(self.stdout, data)
      end

      stdout_line_buffer = data[#data]
    end,
    on_stderr = function(_, data)
      data[1] = stderr_line_buffer .. data[1]

      for i=1,#data-1 do
        local data = data[i]:gsub("\r", "")
        if type(self.on_stderr) == "function" then
          self.on_stderr(data)
        end
        table.insert(self.stderr, data)
      end

      stderr_line_buffer = data[#data]
    end,
  })
end

--- Returns when the job is finished
function Job:wait()
  vim.fn.jobwait({ self.channel })
end

--- Writes the given strings to the stdin
-- This function also closes stdin so it can only be called once
--@tparam {string, ...} lines a list of strings
function Job:write(lines)
  vim.fn.chansend(self.channel, lines)
  vim.fn.chanclose(self.channel, "stdin")
end

function Job.batch(cmds)
  return util.map(cmds, function(cmd)
    return Job.new({ cmd = cmd })
  end)
end

function Job.start_all(jobs)
  for _,job in pairs(jobs) do
    job:start()
  end
end

function Job.wait_all(jobs)
  vim.fn.jobwait(util.map(jobs, function(job) 
    return job.channel 
  end))
end

return Job
