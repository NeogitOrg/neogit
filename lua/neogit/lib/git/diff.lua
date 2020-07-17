local util = require("neogit.lib.util")
local cli = require("neogit.lib.git.cli")

local function parse_diff(output)
  local diff = {
    lines = output,
    hunks = {}
  }

  local len = #output

  local hunk = {}

  for i=1,len do
    local is_new_hunk = #vim.fn.matchlist(output[i], "^@@") ~= 0
    if is_new_hunk then
      if hunk.first ~= nil then
        table.insert(diff.hunks, hunk)
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
  staged = function(name)
    return parse_diff(util.slice(cli.run("diff --cached " .. name), 5))
  end,
  unstaged = function(name)
    return parse_diff(util.slice(cli.run("diff " .. name), 5))
  end,
}
