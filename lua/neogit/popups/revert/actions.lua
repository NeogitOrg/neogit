local a = require("plenary.async")
local status = require("neogit.status")
local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

-- TODO: support multiple commits
function M.commits(popup)
  local commits
  if popup.state.env.commit[1] then
    commits = popup.state.env.commit
  else
    local commit_list = util.filter_map(git.log.list(), function(entry)
      if entry.oid then
        return string.format("%s %s", entry.oid:sub(1, 8), entry.description[1])
      end
    end)

    -- TODO: Integrate telescope's make_entry.from_git_commit if telescope is integrated
    -- https://github.com/nvim-telescope/telescope.nvim/blob/00cf15074a2997487813672a75f946d2ead95eb0/lua/telescope/make_entry.lua#L411
    commits = FuzzyFinderBuffer.new(commit_list):open_async { allow_multi = false }
    commits = util.map({ commits }, function(commit)
      return commit:match("(%x%x%x%x%x%x%x%x+)")
    end)
  end

  if not commits[1] then
    return
  end

  a.util.scheduler()
  git.revert.commits(commits, popup:get_arguments())
  a.util.scheduler()
  status.refresh(true, "revert_commits")
end

return M
