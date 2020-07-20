local history = {}
local cli = {
  run = function(cmd)
    local output = vim.fn.systemlist("git " .. cmd)
    table.insert(history, {
      cmd = "git " .. cmd,
      output = output,
      code = vim.v.shell_error
    })
    return output
  end,
  history = history
}

return cli
