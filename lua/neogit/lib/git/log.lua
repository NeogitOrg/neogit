local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")
local a = require('neogit.async')

local function parse_log(output)
  output = vim.split(output, '\n')
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
  list = a.sync(function(options)
    options = util.split(options, ' ')
    local output = a.wait(cli.log.oneline.args(unpack(options)).call())
    return parse_log(output)
  end),
  parse_log = parse_log
}
