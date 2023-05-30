local cli = require("neogit.lib.git.cli")

return {
  cli = cli,
  init = require("neogit.lib.git.init"),
  status = require("neogit.lib.git.status"),
  stash = require("neogit.lib.git.stash"),
  fetch = require("neogit.lib.git.fetch"),
  log = require("neogit.lib.git.log"),
  reflog = require("neogit.lib.git.reflog"),
  branch = require("neogit.lib.git.branch"),
  diff = require("neogit.lib.git.diff"),
  rebase = require("neogit.lib.git.rebase"),
  merge = require("neogit.lib.git.merge"),
  cherry_pick = require("neogit.lib.git.cherry_pick"),
  reset = require("neogit.lib.git.reset"),
  remote = require("neogit.lib.git.remote"),
  config = require("neogit.lib.git.config"),
}
