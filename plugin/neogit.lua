local api = vim.api

api.nvim_create_user_command("Neogit", function(o)
  local neogit = require("neogit")
  neogit.open(require("neogit.lib.util").parse_command_args(o.fargs))
end, {
  nargs = "*",
  desc = "Open Neogit",
  complete = function(arglead)
    local neogit = require("neogit")
    return neogit.complete(arglead)
  end,
})

api.nvim_create_user_command("NeogitResetState", function()
  require("neogit.lib.state")._reset()
end, { nargs = "*", desc = "Reset any saved flags" })

api.nvim_create_user_command("NeogitLogCurrent", function(args)
  local action = require("neogit").action
  local path = vim.fn.expand(args.fargs[1] or "%")

  if args.range > 0 then
    action("log", "log_current", { "-L" .. args.line1 .. "," .. args.line2 .. ":" .. path })()
  else
    action("log", "log_current", { "--", path })()
  end
end, {
  nargs = "?",
  desc = "Open git log (current) for specified file, or current file if unspecified. Optionally accepts a range.",
  range = "%",
  complete = "file",
})

api.nvim_create_user_command("NeogitCommit", function(args)
  local commit = args.fargs[1] or "HEAD"
  local CommitViewBuffer = require("neogit.buffers.commit_view")
  CommitViewBuffer.new(commit):open()
end, {
  nargs = "?",
  desc = "Open git commit view for specified commit, or HEAD",
})
