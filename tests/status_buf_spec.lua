local eq = assert.are.same

-- very naiive implementation, we only use this to generate unique folder names
math.randomseed(os.clock()^5)
local function random_string(length)
	local res = ""
	for _ = 1, length do
		res = res .. string.char(math.random(97, 122))
	end
	return res
end

local function prepare_repository(dir)
  vim.cmd('silent !cp -r tests/.repo/ /tmp/'..dir)
  vim.cmd('cd /tmp/'..dir)
  vim.cmd('silent !cp -r .git.orig/ .git/')
end

local function cleanup_repository(dir)
  vim.cmd('cd -')
  vim.cmd('silent !rm -rf /tmp/'..dir)
end

local function in_prepared_repo(cb)
  return function ()
    local dir = 'neogit_test_'..random_string(5)
    prepare_repository(dir)
    __NeogitStatusRefresh(true)()
    vim.cmd('Neogit')
    local _, err = pcall(cb)
    cleanup_repository(dir)
    if err ~= nil then
      error(err)
    end
  end
end

local function get_git_status(files)
  local result = vim.api.nvim_exec('!git status -s --porcelain=1 -- ' .. (files or ''), true)
  local lines = vim.split(result, '\n')
  local output = {}
  for i=3,#lines do
    table.insert(output, lines[i])
  end
  return table.concat(output, '\n')
end

local function get_git_diff(files, flags)
  local result = vim.api.nvim_exec('!git diff '..(flags or '')..' -- ' ..(files or ''), true)
  local lines = vim.split(result, '\n')
  local output = {}
  for i=5,#lines do
    table.insert(output, lines[i])
  end
  return table.concat(output, '\n')
end

describe('staging files - s', function ()
  it('can stage an untracked file under the cursor', in_prepared_repo(function ()
    vim.fn.setpos('.', {0, 5, 1, 0})
    vim.cmd('normal s')
    local result = get_git_status('untracked.txt')
    eq('A  untracked.txt\n', result)
  end))

  it('can stage a tracked file under the cursor', in_prepared_repo(function ()
    vim.fn.setpos('.', {0, 8, 1, 0})
    vim.cmd('normal s')
    local result = get_git_status('a.txt')
    eq('M  a.txt\n', result)
  end))

  it('can stage a hunk under the cursor of a tracked file', in_prepared_repo(function ()
    vim.fn.setpos('.', {0, 8, 1, 0})
    vim.cmd('normal zajjs')
    eq('MM a.txt\n', get_git_status('a.txt'))
    eq([[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,5 @@
 This is a text file under version control.
-It exists so it can be manipulated by the test suite.
+This is a change made to a tracked file.
 Here are some lines we can change during the tests.
 
 
]], get_git_diff('a.txt', '--cached'))
  end))

  it('can stage from a selection in a hunk', in_prepared_repo(function ()
    vim.fn.setpos('.', {0, 8, 1, 0})
    vim.cmd('normal zajjjjVs')
    eq('MM a.txt\n', get_git_status('a.txt'))
    eq([[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,6 @@
 This is a text file under version control.
 It exists so it can be manipulated by the test suite.
+This is a change made to a tracked file.
 Here are some lines we can change during the tests.
 
 
]], get_git_diff('a.txt', '--cached'))
  end))

end)
