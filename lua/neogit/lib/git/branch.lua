local a = require 'plenary.async'
local cli = require('neogit.lib.git.cli')
local input = require('neogit.lib.input')
local M = {}

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

function M.get_all_branches()
  local branches = cli.branch
    .list
    .all
    .call()

  return parse_branches(branches)
end

function M.get_upstream()
  local full_name = cli["rev-parse"].abbrev_ref().show_popup(false).args("@{upstream}").call()
  local current = cli.branch.current.show_popup(false).call()

  if #full_name > 0 and #current > 0 then
    local remote = cli.config
      .show_popup(false)
      .get(string.format("branch.%s.remote", current[1]))
      .call()
    if #remote > 0 then
      return {
        remote = remote[1],
        branch = full_name[1]:sub(#remote[1] + 2, -1),
      }
    end
  end
end

function M.prompt_for_branch(options)
  a.util.scheduler()
  local chosen = input.get_user_input_with_completion('branch > ', options)
  if not chosen or chosen == '' then return nil end

  local truncate_remote_name = chosen:match('.+/.+/(.+)')
  if truncate_remote_name and truncate_remote_name ~= '' then
    return truncate_remote_name
  end

  return chosen
end

function M.checkout_local()
  local branches = get_local_branches()

  a.util.scheduler()
  local chosen = M.prompt_for_branch(branches)
  if not chosen then return end
  cli.checkout.branch(chosen).call()
end

function M.checkout()
  local branches = M.get_all_branches()

  a.util.scheduler()
  local chosen = M.prompt_for_branch(branches)
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
  local branches = M.get_all_branches()

  a.util.scheduler()
  local chosen = M.prompt_for_branch(branches)
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

return M
