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
        FuzzyFinderBuffer.value = { test_branch, "worktree-folder" }

        local worktrees = harness.exec { "git", "worktree", "list" }
        assert.are.same(worktrees[2], "")

        act("ww")
        operations.wait("checkout_worktree")

        worktrees = harness.exec { "git", "worktree", "list" }
        local path, _, _, branch = unpack(vim.split(worktrees[2], " "))
        assert.are.same(branch, "[" .. test_branch .. "]")
        assert.are.same(path:match("/worktree%-folder$"), "/worktree-folder")
        assert.are.same(path, vim.loop.cwd())
      end)
    )
  end)

  describe("Worktree Create", function()
    it(
      "Chooses a directory and branch to base from",
      in_prepared_repo(function()
        FuzzyFinderBuffer.value = { "worktree-folder-create", "master" }
        input.values = { "new-worktree-branch" }

        local worktrees = harness.exec { "git", "worktree", "list" }
        assert.are.same(worktrees[2], "")

        act("wW")
        operations.wait("create_worktree")

        worktrees = harness.exec { "git", "worktree", "list" }
        local path, _, _, branch = unpack(vim.split(worktrees[2], " "))
        assert.are.same(branch, "[new-worktree-branch]")
        assert.are.same(path:match("/worktree%-folder%-create$"), "/worktree-folder-create")
        assert.are.same(path, vim.loop.cwd())
      end)
    )
  end)

  describe("Worktree Goto", function()
    it(
      "Changes CWD to the worktree path",
      in_prepared_repo(function()
        -- Build a new worktree
        harness.exec { "git", "branch", "a-new-goto" }
        local worktrees = harness.exec { "git", "worktree", "list" }
        local main_path, _, _, _ = unpack(vim.split(worktrees[1], " "))

        FuzzyFinderBuffer.value = { "a-new-goto", "worktree-folder-goto", main_path }

        act("ww")
        operations.wait("checkout_worktree")

        worktrees = harness.exec { "git", "worktree", "list" }
        local path, _, _, branch = unpack(vim.split(worktrees[2], " "))
        assert.are.same(path, vim.loop.cwd())

        -- Test that we can goto the main tree
        act("wg")
        operations.wait("visit_worktree")
        assert.are.same(main_path, vim.loop.cwd())
      end)
    )
  end)

  -- describe("Worktree Move", function()
  --   it(
  --     "Can move a worktree from one dir to another",
  --     in_prepared_repo(function()
  --       -- Setup
  --       local test_branch = "a-new-branch-tree"
  --
  --       harness.exec { "git", "branch", test_branch }
  --       FuzzyFinderBuffer.value = { test_branch, "worktree-folder" }
  --
  --       act("ww")
  --       operations.wait("checkout_worktree")
  --
  --       local worktrees = harness.exec { "git", "worktree", "list" }
  --       local path, _, _, branch = unpack(vim.split(worktrees[2], " "))
  --       assert.are.same(branch, "[" .. test_branch .. "]")
  --       assert.are.same(path:match("/worktree%-folder$"), "/worktree-folder")
  --       assert.are.same(path, vim.loop.cwd())
  --     end)
  --   )
  -- end)

  -- describe("Worktree Delete", function()
  --   it(
  --     "Can remove a worktree",
  --     in_prepared_repo(function()
  --       local test_branch = "a-new-branch-tree"
  --
  --       harness.exec { "git", "branch", test_branch }
  --       FuzzyFinderBuffer.value = { test_branch, "worktree-folder" }
  --
  --       local worktrees = harness.exec { "git", "worktree", "list" }
  --       assert.are.same(worktrees[2], "")
  --
  --       act("ww")
  --       operations.wait("checkout_worktree")
  --
  --       worktrees = harness.exec { "git", "worktree", "list" }
  --       local path, _, _, branch = unpack(vim.split(worktrees[2], " "))
  --       assert.are.same(branch, "[" .. test_branch .. "]")
  --       assert.are.same(path:match("/worktree%-folder$"), "/worktree-folder")
  --       assert.are.same(path, vim.loop.cwd())
  --     end)
  --   )
  -- end)
end)
