local util = require("neogit.lib.util")
local cli = require("neogit.lib.git.cli")

local function parse_diff(output)
  output = util.slice(output, 5)
  local diff = {
    lines = output,
    hunks = {}
  }

  local len = #output

  local hunk = nil

  for i=1,len do
    local is_new_hunk = #vim.fn.matchlist(output[i], "^@@") ~= 0
    if is_new_hunk then
      if hunk ~= nil then
        table.insert(diff.hunks, hunk)
        hunk = {}
      else
        hunk = {}
      end
      hunk.first = i
      hunk.last = i
    else
      hunk.last = hunk.last + 1
    end
  end

  table.insert(diff.hunks, hunk)

  return diff
end

return {
  parse = parse_diff,
  staged = function(name, cb)
    if cb then
      cli.run("diff --cached " .. name, function(o)
        cb(parse_diff(o))
      end)
    else
      return parse_diff(cli.run("diff --cached " .. name))
    end
  end,
  unstaged = function(name, cb)
    if cb then
      cli.run("diff " .. name, function(o)
        cb(parse_diff(o))
      end)
    else
      return parse_diff(cli.run("diff --cached " .. name))
    end
  end,
}
