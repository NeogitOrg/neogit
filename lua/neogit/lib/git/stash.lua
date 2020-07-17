local cli = require("neogit.lib.git.cli")

return {
  list = function()
    local output = cli.run("stash list")
    local result = {}
    for _, line in ipairs(output) do
      local matches = vim.fn.matchlist(line, "stash@{\\(\\d*\\)}: \\(.*\\)")
      table.insert(result, { idx = tonumber(matches[2]), name = matches[3]})
    end
    return result
  end
}
