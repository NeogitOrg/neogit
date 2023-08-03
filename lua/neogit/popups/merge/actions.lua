local M = {}

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")
local client = require("neogit.client")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

function M.in_merge()
  return git.repo.merge.head
end

local function merge(popup, cmd, msg)
  client.wrap(cmd.arg_list(popup:get_arguments()), {
    autocmd = "NeogitMergeComplete",
    msg = msg or {},
  })
end

function M.commit(popup)
  merge(popup, git.cli.merge.continue)
end

function M.abort(popup)
  if input.get_confirmation("Abort merge?", { values = { "&Yes", "&No" }, default = 2 }) then
    merge(popup, git.cli.merge.abort, { success = "Merge Aborted" })
  end
end

function M.merge(popup)
  local branch = FuzzyFinderBuffer.new(git.branch.get_all_branches()):open_async()
  if branch then
    merge(popup, git.cli.merge, {
      success = string.format("Merged %s into %s", branch, git.branch.current()),
      fail = "Merging failed - Resolve conflicts before continuing",
    })
  end
end

return M
