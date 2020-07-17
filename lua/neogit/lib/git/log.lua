local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

return {
  list = function(options)
    local output = cli.run("log --oneline " .. options)
    local output_len = #output
    local commits = {}

    for i=1,output_len do
      local matches = vim.fn.matchlist(output[i], "^\\([| \\*]*\\)\\([a-zA-Z0-9]*\\) \\((.*)\\)\\? \\?\\(.*\\)")

      if #matches ~= 0 and matches[3] ~= "" then
        local commit = {
          level = util.str_count(matches[2], "|"),
          hash = matches[3],
          remote = matches[4],
          message = matches[5]
        }
        table.insert(commits, commit)
      end
    end

    return commits
  end
}
