local git = {
  cli = require("neogit.lib.git.cli"),
  stash = require("neogit.lib.git.stash")
}
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
  get = function()
    local outputs = git.cli.run_batch({
      "status --porcelain=1 --branch",
      "stash list",
      "log --oneline @{upstream}..",
      "log --oneline ..@{upstream}",
      "log -1 --pretty=%B",
      "log -1 --pretty=%B @{upstream}"
    }, false)

    local result = {
      untracked_files = {},
      unstaged_changes = {},
      unmerged_changes = {},
      staged_changes = {},
      stashes = git.stash.parse(outputs[2]),
      unpulled = util.map(outputs[4], function(x) return { name = x } end),
      unmerged = util.map(outputs[3], function(x) return { name = x } end),
      head = {
        message = outputs[5][1],
        branch = ""
      },
      upstream = nil
    }

    local function insert_change(list, marker, entry)
      local matches = vim.fn.matchlist(entry, "\\(.*\\) -> \\(.*\\)")
      local name, original_name
      if matches[3] ~= nil and matches[3] ~= "" then
        name = matches[3]
        original_name = matches[2]
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

    for _, line in pairs(outputs[1]) do
      local matches = vim.fn.matchlist(line, "\\(.\\{2}\\) \\(.*\\)")
      local marker = matches[2]
      local details = matches[3]

      if marker == "##" then
        local tokens = vim.split(details, "...", true)
        result.head.branch = tokens[1]
        if tokens[2] ~= nil then
          result.upstream = {
            branch = vim.split(tokens[2], " ", true)[1],
            message = outputs[6][1]
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
  end,
  stage = function(name)
    git.cli.run("add " .. name)
  end,
  stage_modified = function()
    git.cli.run("add -u")
  end,
  stage_all = function()
    git.cli.run("add -A")
  end,
  unstage = function(name)
    git.cli.run("reset " .. name)
  end,
  unstage_all = function()
    git.cli.run("reset")
  end,
}

-- status.stage_range(

return status
