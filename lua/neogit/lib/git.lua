local git = {
  branch = require("neogit.lib.git.branch"),
  cherry_pick = require("neogit.lib.git.cherry_pick"),
  cli = require("neogit.lib.git.cli"),
  config = require("neogit.lib.git.config"),
  diff = require("neogit.lib.git.diff"),
  fetch = require("neogit.lib.git.fetch"),
  files = require("neogit.lib.git.files"),
  index = require("neogit.lib.git.index"),
  init = require("neogit.lib.git.init"),
  log = require("neogit.lib.git.log"),
  merge = require("neogit.lib.git.merge"),
  pull = require("neogit.lib.git.pull"),
  push = require("neogit.lib.git.push"),
  rebase = require("neogit.lib.git.rebase"),
  reflog = require("neogit.lib.git.reflog"),
  remote = require("neogit.lib.git.remote"),
  reset = require("neogit.lib.git.reset"),
  revert = require("neogit.lib.git.revert"),
  sequencer = require("neogit.lib.git.sequencer"),
  stash = require("neogit.lib.git.stash"),
  status = require("neogit.lib.git.status"),
}

local repositories = {}

setmetatable(git, {
  __index = function(_, method)
    if method == "repo" then
      local cwd = require("neogit.status").cwd
      if not cwd then
        require("neogit.logger").error("[GIT] Cannot construct repository! No CWD")
        return
      end

      if not repositories[cwd] then
        repositories[cwd] = require("neogit.lib.git.repository").new(cwd)
      end

      require("neogit.logger").info("[GIT] Found repo for " .. cwd)
      return repositories[cwd]
    end
  end,
})

return git
