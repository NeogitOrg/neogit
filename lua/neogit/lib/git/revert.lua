local cli = require("neogit.lib.git.cli")
local client = require("neogit.client")

local M = {}

-- TODO: Add proper support for multiple commits. Gotta do something with the sequencer
function M.commits(commits, args)
  client.wrap(cli.revert.args(table.concat(commits, " ")).arg_list(args), {
    autocmd = "NeogitRevertComplete",
    refresh = "do_revert",
    msg = {
      setup = "Reverting...",
      success = "Reverted!",
      fail = "Couldn't revert",
    },
  })
function M.continue()
  cli.revert.continue.call_sync()
end

function M.skip()
  cli.revert.skip.call_sync()
end

function M.abort()
  cli.revert.abort.call_sync()
end

return M
