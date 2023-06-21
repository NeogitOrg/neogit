local cli = require("neogit.lib.git.cli")
local client = require("neogit.client")

local M = {}

-- TODO: Add proper support for multiple commits. Gotta do something with the sequencer
function M.commits(commits, args)
  client.wrap(
    cli.revert.args(table.concat(commits, " ")).arg_list(args),
    {
      autocmd = "NeogitRevertComplete",
      refresh = "do_revert",
      mgs = {
        setup = "Reverting...",
        success = "Reverted!",
        fail = "Couldn't revert"
      }
    }
  )
end

return M
