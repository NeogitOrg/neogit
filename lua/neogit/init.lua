local branch_re = "On branch \\(\\w\\+\\)"
local remote_re = "Your branch is up to date with '\\(.*\\)'."
local modified_re = ".*modified:\\W*\\(.*\\)"

local function git_status()
  local result = {}
  local output = vim.fn.systemlist("git status")

  result.branch = vim.fn.matchlist(output[1], branch_re)[2]
  result.remote = vim.fn.matchlist(output[2], remote_re)[2]

  local i = 7

  result.modified_files = {}

  while output[i] ~= "" do
    local file = vim.fn.matchlist(output[i], modified_re)[2]
    table.insert(result.modified_files, file)
    i = i + 1
  end

  return result
end

print(vim.inspect(git_status()))
