local a = require("plenary.async")
local eq = assert.are.same
local neogit = require("neogit")
local operations = require("neogit.operations")
local util = require("tests.util.util")
local harness = require("tests.util.git_harness")
local input = require("tests.mocks.input")
local in_prepared_repo = harness.in_prepared_repo
local get_git_status = harness.get_git_status
local get_git_diff = harness.get_git_diff

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
end

local function find(text)
  for index, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
    if line:match(text) then
      vim.api.nvim_win_set_cursor(0, { index, 0 })
      return true
    end
  end
  return false
end

describe("status buffer", function()
  describe("renamed files", function()
    it(
      "correctly tracks renames",
      in_prepared_repo(function()
        harness.exec { "touch", "testfile" }
        harness.exec { "echo", "test file content", ">testfile" }
        harness.exec { "git", "add", "testfile" }
        harness.exec { "git", "commit", "-m", "'added testfile'" }
        harness.exec { "mv", "testfile", "renamed-testfile" }
        harness.exec { "git", "add", "testfile" }
        harness.exec { "git", "add", "renamed-testfile" }

        a.util.block_on(neogit.reset)
        a.util.block_on(neogit.refresh)

        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
        assert.True(vim.tbl_contains(lines, "Renamed testfile -> renamed-testfile"))
      end)
    )
  end)

  describe("staging files - s", function()
    it(
      "Handles non-english filenames correctly",
      in_prepared_repo(function()
        harness.exec { "touch", "你好.md" }
        a.util.block_on(neogit.reset)
        a.util.block_on(neogit.refresh)

        find("你好%.md")
        act("s")
        operations.wait("stage")
        eq("A  你好.md", get_git_status("你好.md"))
      end)
    )

    it(
      "can stage an untracked file under the cursor",
      in_prepared_repo(function()
        find("untracked%.txt")
        act("s")
        operations.wait("stage")
        eq("A  untracked.txt", get_git_status("untracked.txt"))
      end)
    )

    it(
      "can stage a tracked file under the cursor",
      in_prepared_repo(function()
        find("Modified a%.txt")
        eq(" M a.txt", get_git_status("a.txt"))
        act("s")
        operations.wait("stage")
        eq("M  a.txt", get_git_status("a.txt"))
      end)
    )

    it(
      "can stage a hunk under the cursor of a tracked file",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>jjs")
        operations.wait("stage")
        eq("MM a.txt", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,5 @@
 This is a text file under version control.
-It exists so it can be manipulated by the test suite.
+This is a change made to a tracked file.
 Here are some lines we can change during the tests.
 
 
]],
          get_git_diff("a.txt", "--cached")
        )
      end)
    )

    it(
      "can stage a subsequent hunk under the cursor of a tracked file",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>8js")
        operations.wait("stage")
        eq("MM a.txt", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -7,4 +7,5 @@ Here are some lines we can change during the tests.
 
 This is a second block of text to create a second hunk.
 It also has some line we can manipulate.
+Adding a new line right here!
 Here is some more.
]],
          get_git_diff("a.txt", "--cached")
        )
      end)
    )

    it(
      "can stage from a selection in a hunk",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>jjjjVs")
        operations.wait("stage")
        eq("MM a.txt", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,6 @@
 This is a text file under version control.
 It exists so it can be manipulated by the test suite.
+This is a change made to a tracked file.
 Here are some lines we can change during the tests.
 
 
]],
          get_git_diff("a.txt", "--cached")
        )
      end)
    )

    it(
      "can stage a whole file and touched hunk",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>")
        find("untracked%.txt")
        --- 0 untracked.txt
        --- 1
        --- 2 Unstaged
        --- 3 a.txt
        --- 4 HEADER
        --- 5 This is a text file...
        --- 6 -It exists...
        --- 7 +This is a change
        act("V6js")
        operations.wait("stage")
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,4 @@
 This is a text file under version control.
-It exists so it can be manipulated by the test suite.
 Here are some lines we can change during the tests.
 
 
]],
          get_git_diff("a.txt", "--cached")
        )
        eq("A  untracked.txt", get_git_status("untracked.txt"))
      end)
    )
  end)

  describe("unstaging files - u", function()
    it(
      "can unstage a staged file under the cursor",
      in_prepared_repo(function()
        find("Modified b%.txt")
        eq("M  b.txt", get_git_status("b.txt"))
        act("u")
        operations.wait("unstage")
        eq(" M b.txt", get_git_status("b.txt"))
      end)
    )

    it(
      "can unstage a hunk under the cursor of a staged file",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>jju")
        operations.wait("unstage")
        eq("MM b.txt", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]],
          get_git_diff("b.txt", "--cached")
        )
      end)
    )

    it(
      "can unstage from a selection in a hunk",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>jjjjVu")
        operations.wait("unstage")
        eq("MM b.txt", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -1,4 +1,5 @@
 This is another test file.
+Changes here!
 This way, unstaging staged changes can be tested.
 
 
]],
          get_git_diff("b.txt")
        )
      end)
    )

    it(
      "can unstage a subsequent hunk from a staged file",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>8ju")
        operations.wait("unstage")
        eq("MM b.txt", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]],
          get_git_diff("b.txt")
        )
      end)
    )
  end)

  describe("discarding files - x", function()
    it(
      "can discard the changes of a file under the cursor",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("x")
        operations.wait("discard")
        eq("", get_git_status("a.txt"))
      end)
    )

    it(
      "can discard a hunk under the cursor",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>jjx")
        operations.wait("discard")
        eq(" M a.txt", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -7,4 +7,5 @@ Here are some lines we can change during the tests.
 
 This is a second block of text to create a second hunk.
 It also has some line we can manipulate.
+Adding a new line right here!
 Here is some more.
]],
          get_git_diff("a.txt")
        )
      end)
    )

    it(
      "can discard a selection of a hunk",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>jjjjVx")
        operations.wait("discard")
        eq(" M a.txt", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
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
]],
          get_git_diff("a.txt")
        )
      end)
    )

    it(
      "can delete an untracked file",
      in_prepared_repo(function()
        find("untracked%.txt")
        act("x")
        operations.wait("discard")
        eq("", get_git_status("untracked.txt"))
      end)
    )

    it(
      "can discard the changes of a staged file under the cursor",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("x")
        operations.wait("discard")
        eq("", get_git_status("b.txt"))
      end)
    )

    it(
      "can discard a hunk of the staged file under the cursor",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>jjx")
        operations.wait("discard")
        eq("M  b.txt", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]],
          get_git_diff("b.txt", "--cached")
        )
      end)
    )

    it(
      "can discard a selection of a staged file",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>jjjjVx")
        operations.wait("discard")
        eq("M  b.txt", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
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
]],
          get_git_diff("b.txt", "--cached")
        )
      end)
    )
    local function produce_merge_conflict(file, change)
      util.system("git commit -am 'WIP'")
      util.system("git switch second-branch")
      util.system("sed -i '" .. change .. "' " .. file)
      util.system("git commit -am 'conflict'")
      util.system("git merge master", true)
      eq("UU " .. file, get_git_status(file))
      a.util.block_on(status.reset)
      a.util.block_on(status.refresh)
      eq(true, find("Both Modified"))
    end
    it(
      "can discard a conflicted file with [O]urs",
      in_prepared_repo(function()
        produce_merge_conflict("a.txt", "s/manipulated/MANIPULATED/g")
        input.choice = "o"

        act("x")
        operations.wait("discard")

        eq("", get_git_status("a.txt"))
        util.system(
          "grep -q MANIPULATED a.txt",
          false,
          "Expected that after taking OUR changes we have 'MANIPULATED' in 'a.txt'"
        )
      end)
    )
    it(
      "can discard a conflicted file with [T]heirs",
      in_prepared_repo(function()
        produce_merge_conflict("a.txt", "s/manipulated/MANIPULATED/g")
        input.choice = "t"

        act("x")
        operations.wait("discard")

        eq("M  a.txt", get_git_status("a.txt"))
        util.system(
          "grep -vq MANIPULATED a.txt",
          false,
          "Expected that after taking THEIR changes we don't have 'MANIPULATED' in 'a.txt' anymore"
        )
      end)
    )
    it(
      "can abort discarding a conflicted file, leaving it conflicted",
      in_prepared_repo(function()
        produce_merge_conflict("a.txt", "s/manipulated/MANIPULATED/g")
        input.choice = "a"

        act("x")
        operations.wait("discard")

        eq("UU a.txt", get_git_status("a.txt"))
      end)
    )
    it(
      "quitting choice prompt does abort discard of conflicted file",
      in_prepared_repo(function()
        produce_merge_conflict("a.txt", "s/manipulated/MANIPULATED/g")
        input.choice = nil -- simulate user pressed ESC

        act("x")
        operations.wait("discard")

        eq("UU a.txt", get_git_status("a.txt"))
      end)
    )
  end)
end)
