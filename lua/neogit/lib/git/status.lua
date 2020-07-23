package.loaded['neogit.lib.git.status'] = nil

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
  stage_range = function(name, diff, hunk)
    local metadata = vim.split(git.cli.run("ls-files -s " .. name)[1], " ")
    local mode = metadata[1]
    local hash = metadata[2]
    local file_index = git.cli.run("cat-file -p " .. hash)
    local file_index_len = #file_index
    local diff_len = #diff
    local new_file = {}

    for i=1,hunk.index_from-1 do
      table.insert(new_file, file_index[i])
    end
    for i=hunk.index_from,hunk.index_from + diff_len do
      local diff_line = vim.fn.matchlist(diff[i - hunk.index_from + 1], "^\\([+ -]\\)\\(.*\\)")
      if diff_line[2] == "+" or diff_line[2] == " " then
        table.insert(new_file, diff_line[3])
      end
    end
    for i=hunk.index_from + hunk.index_len,file_index_len do
      table.insert(new_file, file_index[i])
    end

    table.insert(new_file, "")

    local output = git.cli.run_with_stdin("hash-object -w --stdin", new_file)
    git.cli.run(string.format("update-index --cacheinfo %d %s %s", mode, output[1], name))
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
  unstage_range = function(name, diff, hunk)
    local metadata = vim.split(git.cli.run("ls-files -s " .. name)[1], " ")
    local mode = metadata[1]
    local hash = metadata[2]
    local file_index = git.cli.run("cat-file -p " .. hash)
    local file_index_len = #file_index
    local diff_len = #diff
    local new_file = {}

    for i=1,hunk.disk_from-1 do
      table.insert(new_file, file_index[i])
    end
    for i=hunk.disk_from,hunk.disk_from + diff_len do
      local diff_line = vim.fn.matchlist(diff[i - hunk.disk_from + 1], "^\\([+ -]\\)\\(.*\\)")
      if diff_line[2] == "-" or diff_line[2] == " " then
        table.insert(new_file, diff_line[3])
      end
    end
    for i=hunk.disk_from + hunk.disk_len,file_index_len do
      table.insert(new_file, file_index[i])
    end

    table.insert(new_file, "")

    local output = git.cli.run_with_stdin("hash-object -w --stdin", new_file)
    git.cli.run(string.format("update-index --cacheinfo %d %s %s", mode, output[1], name))
  end,
  unstage_all = function()
    git.cli.run("reset")
  end,
}

return status
