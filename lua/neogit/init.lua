local branch_re = "On branch \\(\\w\\+\\)"
local remote_re = "Your branch is \\(up to date with\\|ahead of\\) '\\(.*\\)' \\?\\(by \\(\\d*\\) commit\\)\\?"
local change_re = "\\W*\\(.*\\):\\W*\\(.*\\)"

local function git_status()
  local output = vim.fn.systemlist("git status")

  local result = {}
  local lineidx = 1

  result.committed_changes = {}
  result.uncommitted_changes = {}
  result.untracked_files = {}

  result.branch = vim.fn.matchlist(output[lineidx], branch_re)[2]
  lineidx = lineidx + 1

  local matches = vim.fn.matchlist(output[lineidx], remote_re)
  result.ahead_by = tonumber(matches[5]) or 0
  result.remote = matches[3]
  lineidx = lineidx + 1

  while output[lineidx] ~= "" do
    lineidx = lineidx + 1
  end

  lineidx = lineidx + 1

  if output[lineidx] == "Changes to be committed:" then
    lineidx = lineidx + 2 -- skip explanation

    while output[lineidx] ~= "" do
      local matches = vim.fn.matchlist(output[lineidx], change_re)
      local type = matches[2]
      local file = matches[3]
      table.insert(result.committed_changes, { type = type, file = file })
      lineidx = lineidx + 1
    end

    lineidx = lineidx + 1
  end

  if output[lineidx] == "Changes not staged for commit:" then
    lineidx = lineidx + 3 -- skip explanation

    while output[lineidx] ~= "" do
      local matches = vim.fn.matchlist(output[lineidx], change_re)
      local type = matches[2]
      local file = matches[3]
      table.insert(result.uncommitted_changes, { type = type, file = file })
      lineidx = lineidx + 1
    end

    lineidx = lineidx + 1
  end

  if output[lineidx] == "Untracked files:" then
    lineidx = lineidx + 2 -- skip explanation

    while output[lineidx] ~= "" do
      local file = string.sub(output[lineidx], 2)
      table.insert(result.untracked_files, file)
      lineidx = lineidx + 1
    end
  end

  return result
end

print(vim.inspect(git_status()))
