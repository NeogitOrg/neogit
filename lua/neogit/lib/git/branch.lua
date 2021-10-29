local a = require 'plenary.async'
local cli = require('neogit.lib.git.cli')
local logger = require('neogit.logger')
local input = require('neogit.lib.input')
local M = {}

local function contains(table, val)
   for i=1,#table do
      if table[i] == val then
         return true
      end
   end
   return false
end

local function parse_branches(branches)
  local other_branches = {}
  for _, b in ipairs(branches) do
    local branch_name = b:match('^  (.+)')
    if branch_name then 
      table.insert(other_branches, branch_name) 
    end
  end

  return other_branches
end

local function get_local_branches()
  local branches = cli.branch
    .list
    .call()

  return parse_branches(branches)
end

local function get_all_branches()
  local branches = cli.branch
    .list
    .all
    .call()

  return parse_branches(branches)
end

local function get_upstream()
  local upstream_text = cli.branch.tracking.call()

  for _, branch in ipairs(upstream_text) do
    local ups_remote, ups_branch = branch:match([[^%*.+%[(.+)/(.+)%].+]])
    if ups_remote and ups_remote ~= "" and ups_branch and ups_branch ~= "" then
      return {remote=ups_remote, branch=ups_branch}
    end
  end

  return nil
end

local function prompt_for_branch(options)
  local chosen = input.get_user_input_with_completion('branch > ', options)
  if not chosen or chosen == '' then return nil end
  if not contains(options, chosen) then
    logger.fmt_error("ERROR: Branch '%s' doesn't exit", chosen)
    return
  end
  return chosen
end

function M.checkout_local()
  local branches = get_local_branches()

  a.util.scheduler()
  local chosen = prompt_for_branch(branches)
  if not chosen then return end
  cli.checkout.branch(chosen).call()
end

function M.checkout()
  local branches = get_all_branches()

  a.util.scheduler()
  local chosen = prompt_for_branch(branches)
  if not chosen then return end
  cli.checkout.branch(chosen).call()
end

function M.create()
  a.util.scheduler()
  local name = input.get_user_input('branch > ')
  if not name or name == '' then return end

  cli.interactive_git_cmd(tostring(cli.branch.name(name)))

  return name
end

function M.delete()
  local branches = get_all_branches()

  a.util.scheduler()
  local chosen = prompt_for_branch(branches)
  if not chosen then return end

  cli.interactive_git_cmd(tostring(cli.branch.delete.name(chosen)))

  return chosen
end

function M.checkout_new()
  a.util.scheduler()
  local name = input.get_user_input('branch > ')
  if not name or name == '' then return end

  cli.interactive_git_cmd(tostring(cli.checkout.new_branch(name)))
end

M.prompt_for_branch = prompt_for_branch
M.get_all_branches = get_all_branches
M.get_upstream = get_upstream

return M
