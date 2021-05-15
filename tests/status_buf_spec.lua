local eq = assert.are.same
local status = require'neogit.status'
local harness = require'tests.git_harness'
local _ = require 'tests.mocks.input'
local in_prepared_repo = harness.in_prepared_repo
local get_git_status = harness.get_git_status
local get_git_diff = harness.get_git_diff

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys('', 'x') -- flush typeahead
  status.wait_on_current_operation()
end

describe('status buffer', function ()
  describe('staging files - s', function ()
    it('can stage an untracked file under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 5, 1, 0})
      act('s')
      local result = get_git_status('untracked.txt')
      eq('A  untracked.txt\n', result)
    end))

    it('can stage a tracked file under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('s')
      local result = get_git_status('a.txt')
      eq('M  a.txt\n', result)
    end))

    it('can stage a hunk under the cursor of a tracked file', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('<tab>jjs')
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
      act('<tab>8js')
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
      act('<tab>jjjjVs')
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
      vim.fn.setpos('.', {0, 11, 1, 0})
      act('u')
      local result = get_git_status('b.txt')
      eq(' M b.txt\n', result)
    end))

    it('can unstage a hunk under the cursor of a staged file', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 11, 1, 0})
      act('<tab>jju')
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
      vim.fn.setpos('.', {0, 11, 1, 0})
      act('<tab>jjjjVu')
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
      vim.fn.setpos('.', {0, 11, 1, 0})
      act('<tab>8ju')
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

  describe('discarding files - x', function ()
    it('can discard the changes of a file under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('x')
      local result = get_git_status('a.txt')
      eq('', result)
    end))

    it('can discard a hunk under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('<tab>jjx')
      eq(' M a.txt\n', get_git_status('a.txt'))
      eq([[--- a/a.txt
+++ b/a.txt
@@ -7,4 +7,5 @@ Here are some lines we can change during the tests.

 This is a second block of text to create a second hunk.
 It also has some line we can manipulate.
+Adding a new line right here!
 Here is some more.
]], get_git_diff('a.txt'))
    end))

    it('can discard a selection of a hunk', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 8, 1, 0})
      act('<tab>jjjjVx')
      eq(' M a.txt\n', get_git_status('a.txt'))
      eq([[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,4 @@
 This is a text file under version control.
-It exists so it can be manipulated by the test suite.
 Here are some lines we can change during the tests.


@@ -7,4 +6,5 @@ Here are some lines we can change during the tests.

 This is a second block of text to create a second hunk.
 It also has some line we can manipulate.
+Adding a new line right here!
 Here is some more.
]], get_git_diff('a.txt'))
    end))

    it('can delete an untracked file', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 5, 1, 0})
      act('x')
      local result = get_git_status('untracked.txt')
      eq('', result)
    end))

    it('can discard the changes of a staged file under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 11, 1, 0})
      act('x')
      local result = get_git_status('b.txt')
      eq('', result)
    end))

    it('can discard a hunk of the staged file under the cursor', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 11, 1, 0})
      act('<tab>jjx')
      eq('M  b.txt\n', get_git_status('b.txt'))
      eq([[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]], get_git_diff('b.txt', '--cached'))
    end))

    it('can discard a selection of a staged file', in_prepared_repo(function ()
      vim.fn.setpos('.', {0, 11, 1, 0})
      act('<tab>jjjjVx')
      eq('M  b.txt\n', get_git_status('b.txt'))
      eq([[--- a/b.txt
+++ b/b.txt
@@ -1,5 +1,4 @@
 This is another test file.
-It will have staged changes.
 This way, unstaging staged changes can be tested.


@@ -7,3 +6,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]], get_git_diff('b.txt', '--cached'))
    end))
  end)
end)
