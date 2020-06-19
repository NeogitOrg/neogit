local branch_re = "On branch \\(\\w\\+\\)"
local remote_re = "Your branch \\(is up to date with\\|is ahead of\\|is behind\\|and\\) '\\(.*\\)' \\?\\(by \\(\\d*\\) commit\\|have diverged\\)\\?"
local change_re = "\\W*\\(.*\\):\\W*\\(.*\\)"

local function git_status()
  local output = vim.fn.systemlist("git status")
  local lineidx = 1

  local function parse_current_line(regex)
    return vim.fn.matchlist(output[lineidx], regex)
  end

  local function parse_changes(list)
    while output[lineidx] ~= "" do
      local matches = parse_current_line(change_re)
      local type = matches[2]
      local file = matches[3]
      table.insert(list, { type = type, file = file })
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

  if matches[2] == "ahead of" then
    result.ahead_by = tonumber(matches[5])
  elseif matches[2] == "behind" then
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
      table.insert(result.untracked_files, file)
      lineidx = lineidx + 1
    end
  end

  return result
end

local function git_tree()
  local output = vim.fn.systemlist("git log --graph --pretty=oneline --abbrev-commit")
  return output
end

local function git_fetch()
  local output = vim.fn.systemlist("git fetch")
  return output
end

local function git_unpulled(branch)
  local output = vim.fn.systemlist("git log --oneline .." .. branch)
  return output
end

local function git_stashes()
  local output = vim.fn.systemlist("git stash list")
  local result = {}
  for i, line in ipairs(output) do
    local matches = vim.fn.matchlist(line, "stash@{\\(\\d*\\)}: \\(.*\\)")
    table.insert(result, { idx = tonumber(matches[2]), name = matches[3] })
  end
  return result
end

local function git_unmerged(branch)
  local output = vim.fn.systemlist("git log --oneline " .. branch .. "..")
  return output
end

git_status()

return {
  status = git_status,
  fetch = git_fetch,
  stashes = git_stashes,
  unpulled = git_unpulled,
  unmerged = git_unmerged,
  tree = git_tree
}
