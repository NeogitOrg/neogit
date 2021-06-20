local util = require 'neogit.lib.util'
local collect = require 'neogit.lib.collection'
local M = {}

function M.dot(chain)
  local parts = collect(util.split(chain, '%.'))
  return function (tbl)
    parts:each(function (p)
      if tbl then 
        tbl = tbl[p] 
      end
    end)
    return tbl
  end
end

function M.compose(...)
  local funcs = collect({...})
  return function (...)
    return funcs:reduce(function (cur, ...)
      return cur(...)
    end, ...)
  end
end
M.C = M.compose

function M.eq(a)
  return function (b)
    return a == b
  end
end


return M
