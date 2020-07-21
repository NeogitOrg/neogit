local cli = require("neogit.lib.git.cli")

local function parse(output)
  local result = {}
  for _, line in ipairs(output) do
    local matches = vim.fn.matchlist(line, "stash@{\\(\\d*\\)}: \\(.*\\)")
    table.insert(result, { idx = tonumber(matches[2]), name = matches[3]})
  end
  return result
end

return {
  parse = parse,
  list = function()
    local output = cli.run("stash list")
    return parse(output)
  end
}
