local a = require 'plenary.async_lib'
local async, await = a.async, a.await
local cli = require('neogit.lib.git.cli')
local util = require('neogit.lib.util')

local M = {}

M.pull_interactive = a.async(function(remote, branch)
  local cmd = "git pull " .. remote .. " " .. branch

  return a.await(cli.interactive_git_cmd(cmd))
end)

local update_unpulled = async(function (state)
  if not state.upstream.branch then return end

  local result = await(
    cli.log.oneline.for_range('..@{upstream}').show_popup(false).call())

  state.unpulled.files = util.map(result, function (x) 
    return { name = x } 
  end)
end)

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
