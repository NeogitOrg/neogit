local cli = require("neogit.lib.git.cli")

return {
  status = require("neogit.lib.git.status"),
  stash = require("neogit.lib.git.stash"),
  log = require("neogit.lib.git.log"),
  branch = require("neogit.lib.git.branch"),
  cli = cli,
  diff = require("neogit.lib.git.diff"),
}
