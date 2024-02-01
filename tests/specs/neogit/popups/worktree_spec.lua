require("plenary.async").tests.add_to_env()

local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local in_prepared_repo = harness.in_prepared_repo

local input = require("tests.mocks.input")
local FuzzyFinderBuffer = require("tests.mocks.fuzzy_finder")

local git = require("neogit.lib.git")

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
end

local function checkout_worktree(branch)
  harness.exec { "git", "branch", branch }
  FuzzyFinderBuffer.value = { branch, "worktree-folder" }

  act("ww")
  operations.wait("checkout_worktree")
end

local function visit_main()
  FuzzyFinderBuffer.value = { git.worktree.main().path }
  act("wg")
  operations.wait("visit_worktree")
end

describe("worktree popup", function()
  describe("Worktree Checkout", function()
    it(
      "Checks out an existing branch in a new worktree",
      in_prepared_repo(function()
        local test_branch = "a-new-branch-tree"

        harness.exec { "git", "branch", test_branch }
        FuzzyFinderBuffer.value = { test_branch, "worktree-folder" }

        assert.True(#git.worktree.list() == 1)

        act("ww")
        operations.wait("checkout_worktree")

        local worktrees = git.worktree.list()
        assert.are.same(worktrees[2].ref, "refs/heads/a-new-branch-tree")
        assert.are.same(worktrees[2].path:match("/worktree%-folder$"), "/worktree-folder")
        assert.are.same(worktrees[2].path, vim.loop.cwd())
      end)
    )
  end)

  describe("Worktree Create", function()
    it(
      "Chooses a directory and branch to base from",
      in_prepared_repo(function()
        FuzzyFinderBuffer.value = { "worktree-folder-create", "master" }
        input.values = { "new-worktree-branch" }

        assert.True(#git.worktree.list() == 1)

        act("wW")
        operations.wait("create_worktree")

        local worktrees = git.worktree.list()
        assert.are.same(worktrees[2].ref, "refs/heads/new-worktree-branch")
        assert.are.same(worktrees[2].path:match("/worktree%-folder%-create$"), "/worktree-folder-create")
        assert.are.same(worktrees[2].path, vim.loop.cwd())
      end)
    )
  end)

  describe("Worktree Goto", function()
    it(
      "Changes CWD to the worktree path",
      in_prepared_repo(function()
        -- Setup
        checkout_worktree("a-goto-branch")

        local worktrees = git.worktree.list()
        assert.are.same(worktrees[2].path, vim.loop.cwd())

        -- Test
        local main_path = git.worktree.main().path
        FuzzyFinderBuffer.value = { main_path }

        act("wg")
        operations.wait("visit_worktree")

        assert.are.same(main_path, vim.loop.cwd())
      end)
    )
  end)

  describe("Worktree Move", function()
    it(
      "Changes CWD when moving the currently checked out worktree",
      in_prepared_repo(function()
        -- Setup
        checkout_worktree("a-moved-branch-tree")

        -- Test
        local worktrees = git.worktree.list()
        FuzzyFinderBuffer.value = { worktrees[2].path, "../moved-worktree-folder" }

        act("wm")
        operations.wait("move_worktree")

        local worktrees = git.worktree.list()
        assert.are.same(worktrees[2].ref, "refs/heads/a-moved-branch-tree")
        assert.are.same(worktrees[2].path:match("/moved%-worktree%-folder$"), "/moved-worktree-folder")
        assert.are.same(worktrees[2].path, vim.loop.cwd())
      end)
    )

    it(
      "Doesn't change CWD when moving a worktree that isn't currently checked out",
      in_prepared_repo(function()
        -- Setup
        checkout_worktree("test-branch-one")
        visit_main()

        -- Test
        local worktrees = git.worktree.list()
        FuzzyFinderBuffer.value = { worktrees[2].path, "../moved-worktree-folder" }
        local cwd = vim.fn.getcwd()

        act("wm")
        operations.wait("move_worktree")

        assert.are.same(cwd, vim.fn.getcwd())
      end)
    )
  end)

  describe("Worktree Delete", function()
    it(
      "Can remove a worktree",
      in_prepared_repo(function()
        -- Setup
        checkout_worktree("a-deleted-worktree")
        visit_main()

        -- Test
        local worktrees = git.worktree.list()
        assert.are.same(#worktrees, 2)

        FuzzyFinderBuffer.value = { worktrees[2].path }
        input.confirmed = true
        act("wD")
        operations.wait("delete_worktree")

        local worktrees = git.worktree.list()
        assert.are.same(#worktrees, 1)
      end)
    )

    it(
      "Can remove the current worktree",
      in_prepared_repo(function()
        -- Setup
        checkout_worktree("a-deleted-worktree")

        -- Test
        local worktrees = git.worktree.list()
        assert.are.same(#worktrees, 2)
        assert.are.same(worktrees[2].path, vim.fn.getcwd())

        FuzzyFinderBuffer.value = { worktrees[2].path }
        input.confirmed = true

        act("wD")
        operations.wait("delete_worktree")

        local worktrees = git.worktree.list()
        assert.are.same(#worktrees, 1)
        assert.are.same(worktrees[1].path, vim.fn.getcwd())
      end)
    )
  end)
end)
