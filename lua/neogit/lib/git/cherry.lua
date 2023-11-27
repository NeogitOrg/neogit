local M = {}
local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

function M.list(upstream, head)
  local result = cli.cherry.verbose.args(upstream, head).call():trim().stdout
  return util.reverse(util.map(result, function(cherry)
    local status, oid, subject = cherry:match("([%+%-]) (%x+) (.*)")
    return { status = status, oid = oid, subject = subject }
  end))
end

return M
