local git = require("neogit.lib.git")
local operation = require("neogit.operations")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local StashViewBuffer = require("neogit.buffers.stash_list_view")

local M = {}

M.both = operation("stash_both", function(popup)
  git.stash.stash_all(popup:get_arguments())
end)

M.index = operation("stash_index", function(popup)
  git.stash.stash_index(popup:get_arguments())
end)

function M.push(popup)
  local files = FuzzyFinderBuffer.new(git.files.all()):open_async { allow_multi = true }
  if not files or not files[1] then
    return
  end

  git.stash.push(popup:get_arguments(), files)
end

local function use(action, stash)
  local name

  if stash and stash.name then
    name = stash.name
  else
    name = FuzzyFinderBuffer.new(git.stash.list()):open_async()
    if not name then
      return
    end

    name = name:match("(stash@{%d+})")
  end

  if name then
    git.stash[action](name)
  end
end

function M.pop(popup)
  use("pop", popup.state.env.stash)
end

function M.apply(popup)
  use("apply", popup.state.env.stash)
end

function M.drop(popup)
  use("drop", popup.state.env.stash)
end

--- git stash list
function M.list(popup)
  -- This will create a buffer for git stash list
  -- To build the buffer take example from
  -- popups/log/actions.lua L36-40
  StashViewBuffer:open()
end

M.rename = operation("stash_rename", function(popup)
  use("rename", popup.state.env.stash)
end)

return M
