local M = {}
local util = require("neogit.lib.util")

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

function M.commit()
  git.merge.continue()
end

function M.abort()
  if input.get_permission("Abort merge?") then
    git.merge.abort()
  end
end

---@param popup PopupData
---@return string[]
local function get_refs(popup)
  local refs = util.merge({ popup.state.env.commit }, git.refs.list_branches(), git.refs.list_tags())
  util.remove_item_from_table(refs, git.branch.current())

  return refs
end

function M.merge(popup)
  local ref = FuzzyFinderBuffer.new(get_refs(popup)):open_async { prompt_prefix = "Merge" }
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--no-edit")
    git.merge.merge(ref, args)
  end
end

function M.squash(popup)
  local ref = FuzzyFinderBuffer.new(get_refs(popup)):open_async { prompt_prefix = "Squash" }
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--squash")
    git.merge.merge(ref, args)
  end
end

function M.merge_edit(popup)
  local ref = FuzzyFinderBuffer.new(get_refs(popup)):open_async { prompt_prefix = "Merge" }
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--edit")
    util.remove_item_from_table(args, "--ff-only")
    if not vim.tbl_contains(args, "--no-ff") then
      table.insert(args, "--no-ff")
    end

    git.merge.merge(ref, args)
  end
end

function M.merge_nocommit(popup)
  local ref = FuzzyFinderBuffer.new(get_refs(popup)):open_async { prompt_prefix = "Merge" }
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--no-commit")
    util.remove_item_from_table(args, "--ff-only")
    if not vim.tbl_contains(args, "--no-ff") then
      table.insert(args, "--no-ff")
    end

    git.merge.merge(ref, args)
  end
end

return M
