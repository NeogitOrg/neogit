local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")

local a = require("plenary.async")

return {
  pick = function(commit)
    a.util.scheduler()

    local result = cli["cherry-pick"].args(commit).call()
    if result.code ~= 0 then
      notif.create("Cherry Pick failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
    end
  end,
  apply = function(commit)
    a.util.scheduler()

    local result = cli["cherry-pick"].no_commit.args(commit).call()
    if result.code ~= 0 then
      notif.create("Cherry Pick failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
    end
  end,
  continue = function()
    cli["cherry-pick"].continue.call_sync()
  end,
  skip = function()
    cli["cherry-pick"].skip.call_sync()
  end,
  abort = function()
    cli["cherry-pick"].abort.call_sync()
  end,
}
