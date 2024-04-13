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
  -- git stash list has its own options same as git log from git-log(1)
  -- So after uses press `l`, a new popup should show with new options.
  -- After the user selects options and stuff then show the output.
  -- The output is shown in a buffer.
  popup:close() -- from popups/diff/actions.lua

  local p = popup
    .builder()
    :name("NeogitStashPopup")
    :arg_heading("Options")
    :option("f", "follow", { key_prefix = "-" })
    :option("d", "decorate", { default = "no", user_input = true, key_prefix = "-"})
    :group_heading("Grouping 2")
    :action("t", "test")
    :build()

  p:show()

  -- To build the buffer take example from
  -- popups/log/actions.lua L36-40
  -- From `popups/branch/actions.lua`
  StashViewBuffer:open()
end

M.rename = operation("stash_rename", function(popup)
  use("rename", popup.state.env.stash)
end)

return M
