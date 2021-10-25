local Ui = require 'neogit.lib.ui'
local Component = require 'neogit.lib.ui.component'
local Job = require 'neogit.lib.job'
local difflib = require 'neogit.lib.git.diff'
local util = require 'neogit.lib.util'
local common = require 'neogit.buffers.common'

local col = Ui.col
local row = Ui.row
local text = Ui.text

local map = util.map

local List = common.List

local M = {}

local _mode_to_text = {
  M = "Modified",
  N = "New file",
  A = "Added",
  D = "Deleted",
  C = "Copied",
  U = "Updated",
  R = "Renamed"
}

local RemoteHeader = Component.new(function(props)
  return row { 
    text(props.name),
    text ": ",
    text(props.branch),
    text " ",
    text(props.msg or '(no commits)'),
  }
end)

local Section = Component.new(function(props)
  return col {
    row {
      text(props.title),
      text ' (',
      text(#props.items),
      text ')',
    },
    col(props.items)
  }
end)

function M.Status(state)
  return {
    List {
      separator = " ",
      items = {
        col {
          RemoteHeader {
            name = "Head", 
            branch = state.head.branch, 
            msg = state.head.commit_message
          },
          state.upstream.branch and RemoteHeader {
            name = "Upstream", 
            branch = state.upstream.branch, 
            msg = state.upstream.commit_message
          },
        },
        -- #state.untracked_files > 0 and Section { 
        --   title = "Untracked files", 
        --   items = map(state.untracked_files, Diff)
        -- },
        -- #state.unstaged_changes > 0 and Section { 
        --   title = "Unstaged changes", 
        --   items = map(state.unstaged_changes, Diff)
        -- },
        -- #state.staged_changes > 0 and Section { 
        --   title = "Staged changes", 
        --   items = map(state.staged_changes, Diff)
        -- },
        #state.stashes > 0 and Section { 
          title = "Stashes",
          items = map(state.stashes, function(s)
            return row {
              text.highlight("Comment")("stash@{", s.idx, "}: "),
              text(s.message)
            }
          end)
        },
        -- #state.unpulled_changes > 0 and Section { 
        --   title = "Unpulled changes",
        --   items = map(state.unpulled_changes, Diff)
        -- },
        -- #state.unmerged_changes > 0 and Section { 
        --   title = "Unmerged changes",
        --   items = map(state.unmerged_changes, Diff)
        -- },
      }
    }
  }
end

function _load_diffs(repo)
  local cli = require 'neogit.lib.git.cli'

  local unstaged_jobs = map(repo.unstaged.items, function(f)
    return cli.diff.shortstat.patch.files(f.name).to_job()
  end)

  local staged_jobs = map(repo.staged.items, function(f)
    return cli.diff.cached.shortstat.patch.files(f.name).to_job()
  end)

  local jobs = {}

  for _, x in ipairs({ unstaged_jobs, staged_jobs }) do
    for _, j in ipairs(x) do
      table.insert(jobs, j)
    end
  end

  Job.start_all(jobs)
  Job.wait_all(jobs)

  for i, j in ipairs(unstaged_jobs) do
    repo.unstaged.items[i].diff = difflib.parse(j.stdout, true)
  end

  for i, j in ipairs(staged_jobs) do
    repo.staged.items[i].diff = difflib.parse(j.stdout, true)
  end
end

function _TEST()
  local repo = require('neogit').repo
  require('neogit.buffers.status').new({
    head = repo.head,
    upstream = repo.upstream,
    untracked_files = repo.untracked.items,
    unstaged_changes = map(repo.unstaged.items, function(f) return f.diff end),
    staged_changes = map(repo.staged.items, function(f) return f.diff end),
    stashes = repo.stashes.items,
    unpulled_changes = repo.unpulled.items,
    unmerged_changes = repo.unmerged.items,
    recent_changes = repo.recent.items,
  }):open()
end

return M
