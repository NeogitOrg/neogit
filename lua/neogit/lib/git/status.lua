local git = {
  cli = require("neogit.lib.git.cli"),
  stash = require("neogit.lib.git.stash")
}
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
    local outputs = git.cli.run_batch {
      "status --porcelain=1 --branch",
      "stash list",
      "log --oneline @{upstream}..",
      "log --oneline ..@{upstream}",
    }

    local result = {
      unstaged_changes = {},
      staged_changes = {},
      untracked_files = {},
      stashes = git.stash.parse(outputs[2]),
      unpulled = util.map(outputs[4], function(x) return { name = x } end),
      unmerged = util.map(outputs[3], function(x) return { name = x } end),
      branch = "",
      remote = ""
    }

    local function insert_change(list, marker, name)
      table.insert(list, {
        type = marker_to_type(marker),
        name = name,
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

return status
