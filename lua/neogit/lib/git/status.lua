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

local function update_range(name, diff, hunk, from, to, cached)
  local metadata = vim.split(git.cli.run("ls-files -s " .. name)[1], " ")
  local mode = metadata[1]
  local hash = metadata[2]
  local file_index = git.cli.run("cat-file -p " .. hash)
  local file_index_len = #file_index
  local diff_len = #diff
  local diff_start = hunk.index_from
  local diff_end = hunk.index_from + diff_len - 1
  local diff_index_end = hunk.index_from + hunk.index_len - 1
  local mark_add = "+"
  local mark_del = "-"
  local new_file = {}

  from = from or 0
  to = to or diff_len

  if from > to then
    local temp = to
    to = from
    from = to - 1
  end

  if cached then
    mark_add = "-"
    mark_del = "+"
    diff_start = hunk.disk_from
    diff_end = hunk.disk_from + diff_len - 1
    diff_index_end = hunk.disk_from + hunk.disk_len - 1
  end

  for i=1,diff_start - 1 do
    table.insert(new_file, file_index[i])
  end
  for i=diff_start,diff_end do
    local diff_idx = i - diff_start + 1
    local diff_line = vim.fn.matchlist(diff[diff_idx], "^\\([+ -]\\)\\(.*\\)")

    if from <= diff_idx and diff_idx <= to then
      if diff_line[2] ~= mark_del then
        table.insert(new_file, diff_line[3])
      end
    else
      if diff_line[2] ~= mark_add then
        table.insert(new_file, diff_line[3])
      end
    end
  end
  for i=diff_index_end + 1,file_index_len do
    table.insert(new_file, file_index[i])
  end

  table.insert(new_file, "")

  local output = git.cli.run_with_stdin("hash-object -w --stdin", new_file)
  git.cli.run(string.format("update-index --cacheinfo %d %s %s", mode, output[1], name))
end

local status = {
  get = function()
    local outputs = git.cli.run_batch({
      "status --porcelain=1 --branch",
      "stash list",
      "log --oneline @{upstream}..",
      "log --oneline ..@{upstream}"
    }, false)

    local result = {
      untracked_files = {},
      unstaged_changes = {},
      unmerged_changes = {},
      staged_changes = {},
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
        local tokens = vim.split(details, "...", true)
        result.branch = tokens[1]
        result.remote = tokens[2] and vim.split(tokens[2], " ", true)[1] or result.branch
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
  stage_range = function(name, diff, hunk, from, to)
    update_range(name, diff, hunk, from, to, false)
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
  unstage_range = function(name, diff, hunk, from, to)
    update_range(name, diff, hunk, from, to, true)
  end,
  unstage_all = function()
    git.cli.run("reset")
  end,
}

-- status.stage_range(

return status
