local cli = require("neogit.lib.git.cli")

return {
  status = require("neogit.lib.git.status"),
  stash = require("neogit.lib.git.stash"),
  log = require("neogit.lib.git.log"),
  branch = require("neogit.lib.git.branch"),
  cli = cli,
  diff = require("neogit.lib.git.diff"),
  rebase = require("neogit.lib.git.rebase"),
  cherry_pick = require("neogit.lib.git.cherry_pick"),
  reset = require("neogit.lib.git.reset"),
  remote = require("neogit.lib.git.remote"),
  config = require("neogit.lib.git.config"),
}
