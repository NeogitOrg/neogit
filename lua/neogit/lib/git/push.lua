local a = require 'plenary.async_lib'
local async, await = a.async, a.await
local cli = require('neogit.lib.git.cli')
local util = require('neogit.lib.util')

local M = {}

local update_unmerged = async(function (state)
  if not state.upstream.branch then return end

  local result = await(
    cli.log.oneline.for_range('@{upstream}..').show_popup(false).call())

  state.unmerged.files = util.map(util.split(result, '\n'), function (x) return { name = x } end)
end)

function M.register(meta)
  meta.update_unmerged = update_unmerged
end

return M
