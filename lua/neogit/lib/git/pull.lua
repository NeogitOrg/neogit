local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local M = {}

function M.pull_interactive(remote, branch, args)
  local cmd = "git pull " .. remote .. " " .. branch .. " " .. args

  return cli.interactive_git_cmd(cmd)
end

local function update_unpulled(state)
  if not state.upstream.branch then
    vim.notify("No upstream branch")
    return
  end

  print("Querying unpulled")
  local result = cli.log.oneline.for_range("..@{upstream}").show_popup(false).call()
  print("Result: ", vim.inspect(result))

  state.unpulled.items = util.map(result, function(x)
    return { name = x }
  end)
end

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
