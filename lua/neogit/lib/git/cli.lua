return {
  run = function(cmd)
    return vim.fn.systemlist("git " .. cmd)
  end,
}
