local util = require 'neogit.lib.util'
local collect = require 'neogit.lib.collection'
local M = {}

function M.dot(chain)
  local parts = collect(util.split(chain, '%.'))
  return function (tbl)
    parts:each(function (p)
      if tbl then tbl = tbl[p] end
    end)
    return tbl
  end
end

return M
