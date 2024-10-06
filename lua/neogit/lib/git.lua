---@class NeogitGitLib
---@field repo        NeogitRepo
---@field bisect      NeogitGitBisect
---@field branch      NeogitGitBranch
---@field cherry      NeogitGitCherry
---@field cherry_pick NeogitGitCherryPick
---@field cli         NeogitGitCLI
---@field config      NeogitGitConfig
---@field diff        NeogitGitDiff
---@field fetch       NeogitGitFetch
---@field files       NeogitGitFiles
---@field index       NeogitGitIndex
---@field init        NeogitGitInit
---@field log         NeogitGitLog
---@field merge       NeogitGitMerge
---@field pull        NeogitGitPull
---@field push        NeogitGitPush
---@field rebase      NeogitGitRebase
---@field reflog      NeogitGitReflog
---@field refs        NeogitGitRefs
---@field remote      NeogitGitRemote
---@field reset       NeogitGitReset
---@field rev_parse   NeogitGitRevParse
---@field revert      NeogitGitRevert
---@field sequencer   NeogitGitSequencer
---@field stash       NeogitGitStash
---@field status      NeogitGitStatus
---@field tag         NeogitGitTag
---@field worktree    NeogitGitWorktree
---@field hooks       NeogitGitHooks
local Git = {}

setmetatable(Git, {
  __index = function(_, k)
    if k == "repo" then
      return require("neogit.lib.git.repository").instance()
    else
      return require("neogit.lib.git." .. k)
    end
  end,
})

return Git
