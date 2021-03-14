local a = require('neogit.async')
local cli = require('neogit.lib.git.cli')
local util = require('neogit.lib.util')
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

local function parse_branches(output)
  local branches = util.split(output, '\n')
  local other_branches = {}
  for _, b in ipairs(branches) do
    local branch_name = b:match('^  (.+)')
    if branch_name then table.insert(other_branches, branch_name) end
  end

  return other_branches
end

local get_local_branches = a.sync(function ()
  local branches = a.wait(cli.branch
    .list
    .call())

  return parse_branches(branches)
end)

local get_all_branches = a.sync(function ()
  local branches = a.wait(cli.branch
    .list
    .all
    .call())

  return parse_branches(branches)
end)

local function prompt_for_branch(options)
  local chosen = input.get_user_input_with_completion('branch > ', options)
  if not chosen or chosen == '' then return nil end
  if not contains(options, chosen) then
    print('ERROR: Creating a new branch from this dialog is not supported (yet)')
    return
  end
  return chosen
end

M.checkout_local = a.sync(function ()
  local branches = a.wait(get_local_branches())

  a.wait_for_textlock()
  local chosen = prompt_for_branch(branches)
  if not chosen then return end
  a.wait(cli.checkout.branch(chosen).call())
end)

M.checkout = a.sync(function ()
  local branches = a.wait(get_all_branches())

  a.wait_for_textlock()
  local chosen = prompt_for_branch(branches)
  if not chosen then return end
  a.wait(cli.checkout.branch(chosen).call())
end)

M.checkout_new = a.sync(function ()
  a.wait_for_textlock()
  local name = input.get_user_input('branch > ')
  if not name or name == '' then return end
  a.wait(cli.checkout
    .new_branch(name)
    .call())
end)

return M
