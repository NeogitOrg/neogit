local notif = require("neogit.lib.notification")
local Job = require("neogit.lib.job")
local util = require("neogit.lib.util")
local a = require('neogit.async')
local process = require('neogit.process')

local git_root = a.sync(function()
  return vim.trim(a.wait(process.spawn({cmd = 'git', args = {'rev-parse', '--show-toplevel'}})))
end)


local history = {}

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
    vim.schedule(function ()
      notif.create({ "Git Error (" .. job.code .. ")!", "", "Press $ to see the git command history." }, { type = "error" })
    end)
  end
end

local exec = a.sync(function(cmd, args, cwd, stdin)
  args = args or {}
  table.insert(args, 1, cmd)

  local time = os.clock()
  local result, code, errors = a.wait(process.spawn({
    cmd = 'git',
    args = args,
    input = stdin,
    cwd = cwd or a.wait(git_root())
  }))
  handle_new_cmd({
    cmd = cmd .. ' ' .. table.concat(args, ' '),
    stdout = vim.split(result, '\n'),
    stderr = vim.split(errors, '\n'),
    code = code,
    time = os.clock() - time
  }, true)
  --print('git', table.concat(args, ' '), '->', code, errors)

  return result, code, errors
end)

local cli = {
  exec = exec,
  exec_all = a.sync(function(cmds, cwd)
    if #cmds == 0 then return end

    local processes = {}
    local root = cwd or a.wait(git_root())

    if root == nil or root == "" then
      return nil
    end

    for _, cmd in ipairs(cmds) do
      table.insert(processes, exec(cmd.cmd, cmd.args, root))
    end

    return a.wait_all(processes)
  end),
  history = history
}

return cli
