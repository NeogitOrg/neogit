local notif = require("neogit.lib.notification")
local Job = require("neogit.lib.job")
local util = require("neogit.lib.util")

local function get_root_path()
  local job = Job:new("git rev-parse --show-toplevel")

  job:start()
  job:wait()

  local path = job.stdout[1]

  return path
end

local history = {}

local function prepend_git(x)
  return "git " .. x
end

local function handle_new_cmd(job, popup)
  if popup == nil then
    popup = true
  end

  table.insert(history, {
    cmd = job.cmd,
    stdout = job.stdout,
    stderr = job.stderr,
    code = job.code,
    time = job.time
  })

  if popup and job.code ~= 0 then
    notif.create({ "Git Error (" .. job.code .. ")!", "", "Press $ to see the git command history." }, { type = "error" })
  end
end

local cli = {
  run = function(cmd, cb)
    if type(cb) == "function" then
      local job = Job:new(prepend_git(cmd), function(job)
        handle_new_cmd(job)
        cb(job.stdout, job.code, job.stderr)
      end)

      job.cwd = get_root_path()

      job:start()
    else
      local job = Job:new(prepend_git(cmd))

      job.cwd = get_root_path()

      job:start()
      job:wait()

      handle_new_cmd(job)
      return job.stdout
    end
  end,
  run_with_stdin = function(cmd, data)
    local job = Job:new(prepend_git(cmd))

    job.cwd = get_root_path()

    job:start()
    job:write(data)
    job:wait()

    handle_new_cmd(job)

    return job.stdout
  end,
  run_batch = function(cmds, popup)
    local jobs = Job.batch(util.map(cmds, prepend_git))
    local cwd = get_root_path()

    for i,job in pairs(jobs) do
      job.cwd = cwd
    end

    Job.start_all(jobs)
    Job.wait_all(jobs)

    local results = {}

    for i,job in pairs(jobs) do
      handle_new_cmd(job, popup)
      results[i] = job.stdout
    end

    return results
  end,
  history = history
}

return cli
