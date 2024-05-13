local M = {}
local util = require("neogit.lib.util")

local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

function M.in_merge()
  return git.repo.state.merge.head
end

function M.commit()
  git.merge.continue()
end

function M.abort()
  if input.get_permission("Abort merge?") then
    git.merge.abort()
  end
end

function M.merge(popup)
  local refs = util.merge({ popup.state.env.commit }, git.refs.list_branches(), git.refs.list_tags())

  local ref = FuzzyFinderBuffer.new(refs):open_async()
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--no-edit")
    git.merge.merge(ref, args)
  end
end

function M.squash(popup)
  local refs = util.merge({ popup.state.env.commit }, git.refs.list_branches(), git.refs.list_tags())

  local ref = FuzzyFinderBuffer.new(refs):open_async()
  if ref then
    local args = popup:get_arguments()
    table.insert(args, "--squash")
    git.merge.merge(ref, args)
  end
end

function M.merge_edit(popup)
  local refs = util.merge({ popup.state.env.commit }, git.refs.list_branches(), git.refs.list_tags())

  local ref = FuzzyFinderBuffer.new(refs):open_async()
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
  local refs = util.merge({ popup.state.env.commit }, git.refs.list_branches(), git.refs.list_tags())

  local ref = FuzzyFinderBuffer.new(refs):open_async()
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
