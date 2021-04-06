local git = {
  cli = require("neogit.lib.git.cli"),
  stash = require("neogit.lib.git.stash")
}
local a = require('plenary.async_lib')
local async, await = a.async, a.await
local util = require("neogit.lib.util")

local function marker_to_type(m)
  if m == "M" then
    return "Modified"
  elseif m == "A" then
    return "New file"
  elseif m == "D" then
    return "Deleted"
  elseif m == "U" then
    return "Conflict"
  else
    return "Unknown"
  end
end

local update_status = a.sync(function (state)
  local result = await(
    git.cli.status
      .porcelain(2)
      .branch
      .null_terminated
      .call())

  local untracked_files, unstaged_files, staged_files = {}, {}, {}
  local append_original_path

  local head = {}
  local upstream = {}

  for _, l in ipairs(util.split(result, '\0')) do
    if append_original_path then
      append_original_path(l)
    else
      local header, value = l:match('# ([%w%.]+) (.+)')
      if header then
        if header == 'branch.head' then
          head.branch = value
        elseif header == 'branch.oid' then
          head.oid = value
        elseif header == 'branch.upstream' then
          upstream.branch = value
        end
      else
        local kind, rest = l:match('(.) (.+)')
        if kind == '?' then
          table.insert(untracked_files, {
            name = rest
          })
        elseif kind == '!' then
          -- we ignore ignored files for now
        elseif kind == '1' then
          local mode_staged, mode_unstaged, _, _, _, _, _, _, name = rest:match('(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (.+)')
          if mode_staged ~= '.' then
            table.insert(staged_files, {
              mode = mode_staged,
              name = name
            })
          end
          if mode_unstaged ~= '.' then
            table.insert(unstaged_files, {
              mode = mode_unstaged,
              name = name
            })
          end
        elseif kind == '2' then
          local mode_staged, mode_unstaged, _, _, _, _, _, _, _, name = rest:match('(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (%a%d+) (.+)')
          local entry = {
            name = name
          }

          if mode_staged ~= '.' then
            entry.mode = mode_staged
            table.insert(staged_files, entry)
          end
          if mode_unstaged ~= '.' then
            entry.mode = mode_unstaged
            table.insert(unstaged_files, entry)
          end

          append_original_path = function (orig)
            entry.original_name = orig
            append_original_path = nil
          end
        end
      end
    end
  end

  state.head = head
  state.upstream = upstream
  state.untracked.files = untracked_files
  state.unstaged.files = unstaged_files
  state.staged.files = staged_files
end)

local update_branch_information = a.sync(function (state)
  local tasks = {}

  if state.head.oid ~= '(initial)' then
    table.insert(tasks, a.sync(function ()
      local result = a.wait(git.cli.log.max_count(1).pretty('%B').call())
      state.head.commit_message = util.split(result, '\n')[1]
    end)())

    if state.upstream.branch then
      table.insert(tasks, a.sync(function ()
        local result = a.wait(git.cli.log.max_count(1).pretty('%B').for_range('@{upstream}').show_popup(false).call())
        state.upstream.commit_message = util.split(result, '\n')[1]
      end)())
    end
  end

  await_all(tasks)
end)

local status = {
  stage = a.sync(function(name)
    a.wait(git.cli.add.files(name).call())
  end),
  stage_modified = async(function()
    await(git.cli.add.update.call())
  end),
  stage_all = async(function()
    await(git.cli.add.all.call())
  end),
  unstage = async(function(name)
    await(git.cli.reset.files(name).call())
  end),
  unstage_all = async(function()
    await(git.cli.reset.call())
  end),
}

status.register = function (meta)
  meta.update_status = update_status
  meta.update_branch_information = update_branch_information
end

return status
