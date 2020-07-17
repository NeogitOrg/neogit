local util = require("neogit.lib.util")

local branch_re = "On branch \\(\\w\\+\\)"
local remote_re = "Your branch \\(is up to date with\\|is ahead of\\|is behind\\|and\\) '\\(.*\\)' \\?\\(by \\(\\d*\\) commit\\|have diverged\\)\\?"
local change_re = "\\W*\\(.*\\):\\W*\\(.*\\)"

local function cli(cmd)
  return vim.fn.systemlist("git " .. cmd)
end

local function parse_log(output)
  local output_len = #output
  local commits = {}

  for i=1,output_len do
    local matches = vim.fn.matchlist(output[i], "^\\([| \\*]*\\)\\([a-zA-Z0-9]*\\) \\((.*)\\)\\? \\?\\(.*\\)")

    if #matches ~= 0 and matches[3] ~= "" then
      local commit = {
        level = util.str_count(matches[2], "|"),
        hash = matches[3],
        remote = matches[4],
        message = matches[5]
      }
      table.insert(commits, commit)
    end
  end

  return commits
end

local function parse_status(output)
  local lineidx = 1

  local function parse_current_line(regex)
    return vim.fn.matchlist(output[lineidx], regex)
  end

  local function parse_changes(list)
    while output[lineidx] ~= "" do
      local matches = parse_current_line(change_re)

      table.insert(list, {
        type = matches[2],
        name = matches[3],
        diff_open = false,
        diff_height = 0
      })

      lineidx = lineidx + 1
    end
  end

  local function skip_explanation()
    while string.find(output[lineidx], "\t") == nil do
      lineidx = lineidx + 1
    end
  end

  local result = {}

  result.staged_changes = {}
  result.unstaged_changes = {}
  result.untracked_files = {}
  result.ahead_by = 0
  result.behind_by = 0
  result.branch = parse_current_line(branch_re)[2]
  lineidx = lineidx + 1

  local matches = parse_current_line(remote_re)

  if matches[2] == "is ahead of" then
    result.ahead_by = tonumber(matches[5])
  elseif matches[2] == "is behind" then
    result.behind_by = tonumber(matches[5])
  elseif matches[2] == "and" then
    lineidx = lineidx + 1
    local matches = parse_current_line("and have \\(\\d*\\) and \\(\\d*\\)")
    result.ahead_by = tonumber(matches[2])
    result.behind_by = tonumber(matches[3])
  end

  result.remote = matches[3]
  lineidx = lineidx + 1

  while output[lineidx] ~= "" do
    lineidx = lineidx + 1
  end

  lineidx = lineidx + 1

  if output[lineidx] == "You are currently rebasing." then
    lineidx = lineidx + 2
    lineidx = lineidx + 1
  end

  if output[lineidx] == "Changes to be committed:" then
    skip_explanation()

    parse_changes(result.staged_changes)

    lineidx = lineidx + 1
  end

  if output[lineidx] == "Changes not staged for commit:" then
    skip_explanation()

    parse_changes(result.unstaged_changes)

    lineidx = lineidx + 1
  end

  if output[lineidx] == "Untracked files:" then
    skip_explanation()

    while output[lineidx] ~= "" do
      local file = string.sub(output[lineidx], 2)
      table.insert(result.untracked_files, { name = file, diff_height = 0, diff_open = false })
      lineidx = lineidx + 1
    end
  end

  return result
end

function diff(options)
  local output
  if options.cache then
    output = util.slice(cli("diff --cached " .. options.name), 5)
  else
    output = util.slice(cli("diff " .. options.name), 5)
  end

  local diff = {
    lines = output,
    hunks = {}
  }

  local len = #output

  local hunk = {}

  for i=1,len do
    local is_new_hunk = #vim.fn.matchlist(output[i], "^@@") ~= 0
    if is_new_hunk then
      if hunk.first ~= nil then
        table.insert(diff.hunks, hunk)
        hunk = {}
      end
      hunk.first = i
      hunk.last = i
    else
      hunk.last = hunk.last + 1
    end
  end

  table.insert(diff.hunks, hunk)

  return diff
end

local function stage(name)
  cli("add " .. name)
end

local function stage_modified()
  cli("add -u")
end

local function stage_all()
  cli("add -A")
end

local function unstage(name)
  cli("reset " .. name)
end

local function unstage_all()
  cli("reset")
end

local function parse_stashes(output)
  local result = {}
  for i, line in ipairs(output) do
    local matches = vim.fn.matchlist(line, "stash@{\\(\\d*\\)}: \\(.*\\)")
    table.insert(result, { idx = tonumber(matches[2]), name = matches[3]})
  end
  return result
end

return {
  parse_log = parse_log,
  parse_status = parse_status,
  parse_stashes = parse_stashes,
  stage = stage,
  stage_all = stage_all,
  stage_modified = stage_modified,
  unstage = unstage,
  unstage_all = unstage_all,
  diff = diff,
  cli = cli
}
