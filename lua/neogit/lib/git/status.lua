local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")

local function marker_to_type(m)
  if m == "M" then
    return "modified"
  elseif m == "A" then
    return "new file"
  elseif m == "D" then
    return "deleted"
  else
    return "unknown"
  end
end

local status = {
  get = function()
    local outputs = cli.run_batch {
      "status --porcelain=1 --branch",
      "stash list",
    }

    local result = {
      unstaged_changes = {},
      staged_changes = {},
      untracked_files = {},
      stash = {},
      unpulled = {},
      unmerged = {},
      branch = "",
      remote = ""
    }

    local function insert_change(list, marker, name)
      table.insert(list, {
        type = marker_to_type(marker),
        name = name,
        diff_height = 0,
        diff_open = false
      })
    end

    for _, line in pairs(output) do
      local matches = vim.fn.matchlist(line, "\\(.\\{2}\\) \\(.*\\)")
      local marker = matches[2]
      local details = matches[3]

      if marker == "##" then
        matches = vim.fn.matchlist(details, "^\\([a-zA-Z0-9]*\\)...\\(\\S*\\).*")
        result.branch = matches[2]
        result.remote = matches[3]
      elseif marker == "??" then
        insert_change(result.untracked_files, "A", details)
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
    cli.run("add " .. name)
  end,
  stage_modified = function()
    cli.run("add -u")
  end,
  stage_all = function()
    cli.run("add -A")
  end,
  unstage = function(name)
    cli.run("reset " .. name)
  end,
  unstage_all = function()
    cli.run("reset")
  end,
}

return status
