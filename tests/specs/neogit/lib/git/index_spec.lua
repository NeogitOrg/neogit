local eq = assert.are.same

local generate_patch_from_selection = require("neogit.lib.git").index.generate_patch

-- Helper-function to keep the testsuite clean, since the interface to the
-- function under test is quite bloated
local function run_with_hunk(hunk, from, to, reverse)
  local diff_from = 1
  local lines = vim.split(hunk, "\n")
  local header_matches =
    vim.fn.matchlist(lines[1], "@@ -\\(\\d\\+\\),\\(\\d\\+\\) +\\(\\d\\+\\),\\(\\d\\+\\) @@")
  return generate_patch_from_selection({
    first = 1,
    last = #lines,
    index_from = header_matches[2],
    index_len = header_matches[3],
    diff_from = diff_from,
    diff_to = #lines,
    lines = vim.list_slice(lines, 2),
    file = "test.txt",
  }, { from = from, to = to, reverse = reverse })
end

describe("patch creation", function()
  it("creates a patch-formatted string from a hunk", function()
    local patch = run_with_hunk(
      [['@@ -1,1 +1,1 @@
-some line
+another line]],
      1,
      2
    )

    eq(
      [[--- a/test.txt
+++ b/test.txt
@@ -1,1 +1,1 @@
-some line
+another line

]],
      patch
    )
  end)

  it("can take only part of a hunk", function()
    local patch = run_with_hunk(
      [[@@ -1,3 +1,3 @@
 line1
-line2
+line two
line3]],
      2,
      3
    )

    eq(
      [[--- a/test.txt
+++ b/test.txt
@@ -1,3 +1,3 @@
 line1
-line2
+line two
line3

]],
      patch
    )
  end)

  it("removes added lines outside of the selection", function()
    local patch = run_with_hunk(
      [[@@ -1,1 +1,4 @@
 line1
+line2
+line3
+line4]],
      3,
      3
    )

    eq(
      [[--- a/test.txt
+++ b/test.txt
@@ -1,1 +1,2 @@
 line1
+line3

]],
      patch
    )
  end)

  it("keeps removed lines outside of the selection as normal lines", function()
    local patch = run_with_hunk(
      [[@@ -1,2 +1,2 @@
 line1
-line2
+line two]],
      3,
      3
    )

    eq(
      [[--- a/test.txt
+++ b/test.txt
@@ -1,2 +1,3 @@
 line1
 line2
+line two

]],
      patch
    )
  end)

  describe("in reverse", function()
    it("removes removed lines outside of the selection", function()
      local patch = run_with_hunk(
        [[@@ -1,2 +1,2 @@
 line1
-line2
+line two]],
        3,
        3,
        true
      )

      eq(
        [[--- a/test.txt
+++ b/test.txt
@@ -1,1 +1,2 @@
 line1
+line two

]],
        patch
      )
    end)

    it("keeps added lines outside of the selection as normal lines", function()
      local patch = run_with_hunk(
        [[@@ -1,2 +1,2 @@
 line1
-line2
+line two]],
        2,
        2,
        true
      )

      eq(
        [[--- a/test.txt
+++ b/test.txt
@@ -1,3 +1,2 @@
 line1
-line2
 line two

]],
        patch
      )
    end)
  end)
end)
