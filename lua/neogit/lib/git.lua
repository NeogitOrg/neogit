local cli = require("neogit.lib.git.cli")
local a = require('neogit.async')

return {
  status = require("neogit.lib.git.status"),
  stash = require("neogit.lib.git.stash"),
  log = require("neogit.lib.git.log"),
  cli = cli,
  diff = require("neogit.lib.git.diff"),

  apply = a.sync(function (patch, parameters)
    a.wait(cli.exec('apply', parameters, nil, patch))
  end),
  checkout = a.sync(function (params)
    local files = params.files
    table.insert(files, 1, '--')
    a.wait(cli.exec('checkout', files))
  end),
  reset = a.sync(function (params)
    local files = params.files
    table.insert(files, 1, '--')
    a.wait(cli.exec('reset', files))
  end)
}
