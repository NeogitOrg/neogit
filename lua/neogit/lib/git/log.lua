local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")
local config = require("neogit.config")

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

local function update_recent(state)
  local count = config.values.status.recent_commit_count
  if count < 1 then
    return
  end

  local result = cli.log.oneline
    .max_count(count)
    .show_popup(false)
    .call()

  state.recent.items = util.map(result, function (x)
    return { name = x }
  end)
end


return {
  list = function(options)
    options = util.split(options, ' ')
    local output = cli.log.oneline.args(unpack(options)).call()
    return parse_log(output)
  end,
  register = function(meta)
    meta.update_recent = update_recent
  end,
  parse_log = parse_log
}
