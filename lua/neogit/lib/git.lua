local cli = require("neogit.lib.git.cli")
local a = require('neogit.async')

local function command_with_files(name, params)
    local args = params.args or {}
    local files = params.files or {}

    local cmd = name .. " " .. table.concat(args, " ")
    if #files > 0 then
      cmd = cmd .. ' -- ' .. table.concat(files, " ")
    end

    return cmd
end

return {
  status = require("neogit.lib.git.status"),
  stash = require("neogit.lib.git.stash"),
  log = require("neogit.lib.git.log"),
  cli = cli,
  diff = require("neogit.lib.git.diff"),

  apply = a.sync(function (patch, parameters)
    a.wait(cli.exec('apply', parameters, nil, patch))
  end),
  checkout = function (params)
    cli.run(command_with_files('checkout', params))
  end,
  reset = function (params)
    cli.run(command_with_files('reset', params))
  end
}
