local status = require("neogit.status")
local a = require("plenary.async")
local M = {}
local util = require("tests.util.util")

local project_dir = util.project_dir
local bare_repo_path = nil

function M.setup_bare_repo()
  if bare_repo_path ~= nil then
    return bare_repo_path
  end

  local workspace_dir = util.create_temp_dir("base-dir")
  print("BASE DIR: " .. workspace_dir)
  vim.api.nvim_set_current_dir(project_dir)
  util.system("cp -r tests/.repo " .. workspace_dir)
  vim.api.nvim_set_current_dir(workspace_dir)
  util.system([[
    mv ./.repo/.git.orig ./.git
    mv ./.repo/* .
    git config user.email "test@neogit-test.test"
    git config user.name "Neogit Test"
    git add .
    git commit -m "temp commit to be soft unstaged later"
  ]])

  bare_repo_path = util.create_temp_dir("bare-dir")

  print("BARE DIR: " .. bare_repo_path)
  util.system(string.format("git clone --bare %s %s", workspace_dir, bare_repo_path))

  return bare_repo_path
end

function M.prepare_repository()
  M.setup_bare_repo()

  local working_dir = util.create_temp_dir("working-dir")
  vim.api.nvim_set_current_dir(working_dir)
  util.system(string.format("git clone %s %s", bare_repo_path, working_dir))
  util.system("git config user.email 'test@neogit.git'")
  util.system("git config user.name 'Neogit Test User'")
  util.system("git reset --soft HEAD~1")
  util.system("git rm --cached untracked.txt")
  util.system("git restore --staged a.txt")
  util.system("git checkout second-branch")
  util.system("git switch master")
  print("WORKING DIRECTORY: " .. working_dir)

  return working_dir
end

function M.in_prepared_repo(cb)
  return function()
    local dir = M.prepare_repository()
    require("neogit").setup()
    vim.cmd("Neogit")
    a.util.block_on(status.reset)
    local _, err = pcall(cb, dir)
    if err ~= nil then
      error(err)
    end
  end
end

function M.get_git_status(files)
  local result = vim.api.nvim_exec("!git status -s --porcelain=1 -- " .. (files or ""), true)
  local lines = vim.split(result, "\n")
  local output = {}
  for i = 3, #lines do
    table.insert(output, lines[i])
  end
  return table.concat(output, "\n")
end

function M.get_git_diff(files, flags)
  local result = vim.api.nvim_exec("!git diff " .. (flags or "") .. " -- " .. (files or ""), true)
  local lines = vim.split(result, "\n")
  local output = {}
  for i = 5, #lines do
    table.insert(output, lines[i])
  end
  return table.concat(output, "\n")
end

function M.get_git_branches()
  local result = vim.api.nvim_exec("!git branch --list --all", true)
  local lines = vim.split(result, "\n")
  local output = {}
  local current_branch = nil
  for _, l in ipairs(lines) do
    local branch_state, name = l:match("^([* ]) (.+)")
    if branch_state == "*" then
      current_branch = name
    end
    if name then
      table.insert(output, name)
    end
  end
  return output, current_branch
end

function M.get_current_branch()
  local result = vim.api.nvim_exec("!git branch --show-current", true)
  local lines = vim.split(result, "\n")
  return lines[#lines - 1]
end

return M
