require("plenary.async").tests.add_to_env()

local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local in_prepared_repo = harness.in_prepared_repo

local input = require("tests.mocks.input")
local FuzzyFinderBuffer = require("tests.mocks.fuzzy_finder")

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
end

describe("worktree popup", function()
  describe("Worktree Checkout", function()
    it(
      "Checks out an existing branch in a new worktree",
      in_prepared_repo(function()
        local test_branch = "a-new-branch-tree"

        harness.exec { "git", "branch", test_branch }
        FuzzyFinderBuffer.value = { test_branch, "../worktree-folder" }

        local worktrees = harness.exec { "git", "worktree", "list" }
        assert.are.same(worktrees[2], "")

        act("ww")
        operations.wait("checkout_worktree")

        worktrees = harness.exec { "git", "worktree", "list" }
        assert.True(worktrees[2]:match("%[a%-new%-branch%-tree%]$") ~= nil)
      end)
    )
  end)
end)
