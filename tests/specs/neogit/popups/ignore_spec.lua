require("plenary.async").tests.add_to_env()
local eq = assert.are.same
local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local in_prepared_repo = harness.in_prepared_repo
local input = require("tests.mocks.input")

local FuzzyFinderBuffer = require("tests.mocks.fuzzy_finder")

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
end

describe("ignore popup", function()
  describe("shared at top-level", function()
    it(
      "can ignore untracked files in top level of project",
      in_prepared_repo(function()
        local files = harness.exec { "git", "status", "--porcelain=1" }
        eq(files, { " M a.txt", "M  b.txt", "?? untracked.txt", "" })

        FuzzyFinderBuffer.value = { { "untracked.txt" } }

        act("it")
        operations.wait("ignore_shared")

        local files = harness.exec { "git", "status", "--porcelain=1" }

        eq(files, { " M a.txt", "M  b.txt", "?? .gitignore", "" })
        eq(harness.exec { "cat", ".gitignore" }, { "untracked.txt", "" })
      end)
    )
  end)

  describe("shared in sub-directory", function()
    it(
      "can ignore untracked files in subdirectory of project",
      in_prepared_repo(function()
        harness.exec { "mkdir", "subdir" }
        harness.exec { "touch", "subdir/untracked.txt" }
        harness.exec { "touch", "subdir/tracked.txt" }
        harness.exec { "git", "add", "subdir/tracked.txt" }

        local files = harness.exec { "git", "status", "--porcelain=1" }
        eq(files, {
          " M a.txt",
          "M  b.txt",
          "A  subdir/tracked.txt",
          "?? subdir/untracked.txt",
          "?? untracked.txt",
          "",
        })

        input.values = { "subdir" }
        FuzzyFinderBuffer.value = { { "untracked.txt" } }
        act("is")
        operations.wait("ignore_subdirectory")

        local files = harness.exec { "git", "status", "--porcelain=1" }

        eq(files, {
          " M a.txt",
          "M  b.txt",
          "A  subdir/tracked.txt",
          "?? subdir/.gitignore",
          "?? untracked.txt",
          "",
        })

        eq(harness.exec { "cat", "subdir/.gitignore" }, { "untracked.txt", "" })
      end)
    )
  end)

  describe("private local", function()
    it(
      "can ignore for project",
      in_prepared_repo(function()
        local files = harness.exec { "git", "status", "--porcelain=1" }
        eq(files, { " M a.txt", "M  b.txt", "?? untracked.txt", "" })

        FuzzyFinderBuffer.value = { { "untracked.txt" } }
        act("ip")
        operations.wait("ignore_private")

        local files = harness.exec { "git", "status", "--porcelain=1" }

        eq(files, { " M a.txt", "M  b.txt", "" })

        eq(harness.exec { "cat", ".git/info/exclude" }, {
          "# git ls-files --others --exclude-from=.git/info/exclude",
          "# Lines that start with '#' are comments.",
          "# For a project mostly in C, the following would be a good set of",
          "# exclude patterns (uncomment them if you want to use them):",
          "# *.[oa]",
          "# *~",
          "untracked.txt",
          "",
        })
      end)
    )
  end)
end)
