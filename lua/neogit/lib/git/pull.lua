local a = require('neogit.async')
local cli = require('neogit.lib.git.cli')
local util = require('neogit.lib.util')

local M = {}

local update_unpulled = a.sync(function (state)
  if not state.upstream.branch then return end

  local result = a.wait(
    cli.log.oneline.for_range('@{upstream}..').call())

  state.unpulled.files = util.map(util.split(result, '\n'), function (x) return { name = x } end)
end)

function M.register(meta)
  meta.update_unpulled = update_unpulled
end

return M
