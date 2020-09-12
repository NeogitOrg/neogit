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
  on_exit = nil
}

Job.__index = Job

--- Creates a new Job
--@tparam string cmd the command to be executed
--@tparam function? on_exit a callback that gets called when the job exits
function Job:new(cmd, on_exit)
  local this = {
    cmd = cmd,
    on_exit = on_exit
  }

  setmetatable(this, self)

  return this
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
  local started_at = vim.fn.reltime()

  local task = self.cmd

  if vim.fn.has('win32') == 1 then
    task = { 'cmd', '/C', task }
  end

  self.channel = vim.fn.jobstart(task, {
    on_exit = function(_, code)
      self.code = code
      self.done = true
      self.running = false
      self.time = vim.fn.reltimefloat(vim.fn.reltime(started_at)) * 1000

      if type(self.on_exit) == "function" then
        self.on_exit(self)
      end
    end,
    on_stdout = function(_, data)
      local len = #data - 1
      for i=1,len do
        self.stdout[i] = data[i]
      end
    end,
    on_stderr = function(_, data)
      local len = #data - 1
      for i=1,len do
        self.stderr[i] = data[i]
      end
    end,
    stderr_buffered = true,
    stdout_buffered = true
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
    return Job:new(cmd)
  end)
end

function Job.start_all(jobs)
  for _,job in pairs(jobs) do
    job:start()
  end
end

function Job.wait_all(jobs)
  vim.fn.jobwait(util.map(jobs, function(job) return job.channel end))
end

return Job
