local notif = require("neogit.lib.notification")

local last_code = 0
local history = {}

function handle_new_cmd(cmd, output, code)
  table.insert(history, {
    cmd = "git " .. cmd,
    output = output,
    code = code
  })

  last_code = code

  if code ~= 0 then
    notif.create({ "Git Error (" .. code .. ")!", "", "Press $ to see the git command history." }, { type = "error" })
  end
end
local cli = {
  run = function(cmd, cb)
    if type(cb) == "function" then
      local output = nil
      vim.fn.jobstart("git " .. cmd, {
        on_exit = function(_, code)
          handle_new_cmd(cmd, output, code)
          cb(output)
        end,
        on_stdout = function(_, data)
          output = data
        end,
        stdout_buffered = true
      })
    else
      local output = vim.fn.systemlist("git " .. cmd)
      handle_new_cmd(cmd, output, vim.v.shell_error)
      return output
    end
  end,
  run_with_stdin = function(cmd, data)
    local output = nil
    local job = vim.fn.jobstart("git " .. cmd, {
      on_exit = function(_, code)
        handle_new_cmd(cmd, output, code)
      end,
      on_stdout = function(_, data)
        output = data
      end,
      stdout_buffered = true
    })

    vim.fn.chansend(job, data)
    vim.fn.chanclose(job, "stdin")
    vim.fn.jobwait({ job })

    return output
  end,
  run_batch = function(cmds)
    local len = #cmds
    local amount = 0
    local result = {}

    for i, cmd in pairs(cmds) do
      local output = {}

      vim.fn.jobstart("git " .. cmd, {
        on_exit = function(_, code)
          handle_new_cmd(cmd, output, code)

          result[i] = output

          amount = amount + 1
        end,
        on_stdout = function(_, data)
          local len = #data - 1
          for i=1,len do
            output[i] = data[i]
          end
        end,
        stdout_buffered = true
      })
    end

    while true do
      if len == amount then
        break
      end

      vim.cmd("sleep 1 m")
    end

    return result
  end,
  last_code = last_code,
  history = history
}

return cli
