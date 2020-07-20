local history = {}
local cli = {
  run = function(cmd, cb)
    if type(cb) == "function" then
      local output = {}
      vim.fn.jobstart("git " .. cmd, {
        on_exit = function(_, code)
          table.insert(history, {
            cmd = "git " .. cmd,
            output = output,
            code = code
          })
          cb(output)
        end,
        on_stdout = function(_, data)
          table.insert(output, data)
        end
      })
    else
      local output = vim.fn.systemlist("git " .. cmd)
      table.insert(history, {
        cmd = "git " .. cmd,
        output = output,
        code = vim.v.shell_error
      })
      return output
    end
  end,
  run_batch = function(cmds)
    local len = #cmds
    local amount = 0
    local result = {}

    for i, cmd in pairs(cmds) do
      local output = {}

      vim.fn.jobstart("git " .. cmd, {
        on_exit = function(_, code)
          table.insert(history, {
            cmd = "git " .. cmd,
            output = output,
            code = code
          })

          result[i] = output

          amount = amount + 1
        end,
        on_stdout = function(_, data)
          output = data
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
  history = history
}

return cli
