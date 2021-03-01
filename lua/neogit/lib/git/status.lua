local git = {
  cli = require("neogit.lib.git.cli"),
  stash = require("neogit.lib.git.stash")
}
local a = require('neogit.async')
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

local status = {
  get = a.sync(function ()
    local status, stash, unmerged, unpulled, head, upstream = a.wait(git.cli.in_parallel(
      git.cli.status.porcelain(1).branch,
      git.cli.stash.args('list'),
      git.cli.log.oneline.for_range('@{upstream}..'),
      git.cli.log.oneline.for_range('..@{upstream}'),
      git.cli.log.max_count(1).pretty('%B'),
      git.cli.log.max_count(1).pretty('%B').for_range('@{upstream}')
    ).call())

    if status == nil then return nil end

    local result = {
      untracked_files = {},
      unstaged_changes = {},
      unmerged_changes = {},
      staged_changes = {},
      stashes = nil,
      unpulled = util.map(util.split(unpulled, '\n'), function(x) return { name = x } end),
      unmerged = util.map(util.split(unmerged, '\n'), function(x) return { name = x } end),
      head = {
        message = util.split(head, '\n')[1],
        branch = ""
      },
      upstream = nil
    }

    result.stashes = git.stash.parse(util.split(stash, '\n'))

    local function insert_change(list, marker, entry)
      local orig, new = entry:match('^(.-) -> (.*)')

      local name, original_name
      if orig then
        print('matches', orig, new)
        name = new
        original_name = orig
      else
        name = entry
        original_name = nil
      end

      table.insert(list, {
        type = marker_to_type(marker),
        name = name,
        original_name = original_name,
        diff_height = 0,
        diff_content = nil,
        diff_open = false
      })
    end

    for _, line in pairs(util.split(status, '\n')) do
      local marker, details = line:match('(..) (.*)')

      if marker == "##" then
        local tokens = vim.split(details, "...", true)
        result.head.branch = tokens[1]
        if tokens[2] ~= nil then
          result.upstream = {
            branch = vim.split(tokens[2], " ", true)[1],
            message = vim.split(upstream, '\n')[1]
          }
        end
      elseif marker == "??" then
        insert_change(result.untracked_files, "A", details)
      elseif marker == "UU" then
        insert_change(result.unmerged_changes, "U", details)
      else
        local chars = vim.split(marker, "")
        if chars[1] ~= " " then
          insert_change(result.staged_changes, chars[1], details)
        end
        if chars[2] ~= " " then
          insert_change(result.unstaged_changes, chars[2], details)
        end
      end
    end

    return result
  end),
  stage = a.sync(function(name)
    a.wait(git.cli.add.files(name).call())
  end),
  stage_modified = a.sync(function()
    a.wait(git.cli.add.update.call())
  end),
  stage_all = a.sync(function()
    a.wait(git.cli.add.all.call())
  end),
  unstage = a.sync(function(name)
    a.wait(git.cli.reset.files(name).call())
  end),
  unstage_all = a.sync(function()
    a.wait(git.cli.reset.call())
  end),
}

-- status.stage_range(

return status
