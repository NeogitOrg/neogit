local eq = assert.are.same
local status = require'neogit.status'
local harness = require'tests.git_harness'
local in_prepared_repo = harness.in_prepared_repo
local get_git_status = harness.get_git_status
local get_git_diff = harness.get_git_diff

local function act(normal_cmd)
  vim.cmd('normal '..normal_cmd)
  status.wait_on_current_operation()
end

describe('status buffer', function ()
  describe('staging files - s', function ()
    it('can stage an untracked file under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 5, 1, 0})
      act('s')
      status.wait_on_current_operation()
      local result = get_git_status('untracked.txt')
      eq('A  untracked.txt\n', result)
    end))

    it('can stage a tracked file under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('s')
      status.wait_on_current_operation()
      local result = get_git_status('a.txt')
      eq('M  a.txt\n', result)
    end))

    it('can stage a hunk under the cursor of a tracked file', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('zajjs')
      status.wait_on_current_operation()
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

    it('can stage a subsequent hunk under the cursor of a tracked file', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('za8js')
      status.wait_on_current_operation()
      eq('MM a.txt\n', get_git_status('a.txt'))
      eq([[--- a/a.txt
+++ b/a.txt
@@ -7,4 +7,5 @@ Here are some lines we can change during the tests.
 
 This is a second block of text to create a second hunk.
 It also has some line we can manipulate.
+Adding a new line right here!
 Here is some more.
]], get_git_diff('a.txt', '--cached'))
    end))

    it('can stage from a selection in a hunk', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('zajjjjVs')
      status.wait_on_current_operation()
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

  describe('unstaging files - u', function ()
    it('can unstage a staged file under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 24, 1, 0})
      act('u')
      status.wait_on_current_operation()
      local result = get_git_status('b.txt')
      eq(' M b.txt\n', result)
    end))

    it('can unstage a hunk under the cursor of a staged file', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 24, 1, 0})
      act('zajju')
      status.wait_on_current_operation()
      eq('MM b.txt\n', get_git_status('b.txt'))
      eq([[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]], get_git_diff('b.txt', '--cached'))
    end))

    it('can unstage from a selection in a hunk', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 24, 1, 0})
      act('zajjjjVu')
      status.wait_on_current_operation()
      eq('MM b.txt\n', get_git_status('b.txt'))
      eq([[--- a/b.txt
+++ b/b.txt
@@ -1,4 +1,5 @@
 This is another test file.
+Changes here!
 This way, unstaging staged changes can be tested.
 
 
]], get_git_diff('b.txt'))
    end))

    it('can unstage a subsequent hunk from a staged file', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 24, 1, 0})
      act('za8ju')
      status.wait_on_current_operation()
      eq('MM b.txt\n', get_git_status('b.txt'))
      eq([[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]], get_git_diff('b.txt'))
    end))
  end)
end)
