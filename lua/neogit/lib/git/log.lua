local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local function parse_log(output)
  if type(output) == "string" then
    output = vim.split(output, '\n')
  end

  local output_len = #output
  local commits = {}

  for i=1,output_len do
    local level, hash, rest = output[i]:match("([| *]*)([a-zA-Z0-9]+) (.*)")
    if level ~= nil then
      local remote, message = rest:match("%((.-)%) (.*)")
      if remote == nil then
        message = rest
      end

      local commit = {
        level = util.str_count(level, "|"),
        hash = hash,
        remote = remote or "",
        message = message
      }
      table.insert(commits, commit)
    end
  end

  return commits
end

return {
  list = function(options)
    options = util.split(options, ' ')
    local output = cli.log.oneline.args(unpack(options)).call()
    return parse_log(output)
  end,
  parse_log = parse_log
}
