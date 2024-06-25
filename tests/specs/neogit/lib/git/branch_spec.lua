local gb = require("neogit.lib.git.branch")
local neogit = require("neogit")
local git_harness = require("tests.util.git_harness")
local neogit_util = require("neogit.lib.util")
local util = require("tests.util.util")
local input = require("tests.mocks.input")

neogit.setup {}

pending("lib.git.branch", function()
  describe("#exists", function()
    before_each(function()
      git_harness.prepare_repository()
      neogit.reset()
    end)

    it("returns true when branch exists", function()
      assert.True(gb.exists("master"))
    end)

    it("returns false when branch doesn't exist", function()
      assert.False(gb.exists("branch-that-doesnt-exist"))
    end)
  end)

  describe("#is_unmerged", function()
    before_each(function()
      git_harness.prepare_repository()
      neogit.reset()
    end)

    it("returns true when feature branch has commits base branch doesn't", function()
      util.system { "git", "checkout", "-b", "a-new-branch" }
      util.system { "git", "reset", "--hard", "origin/master" }
      util.system { "touch", "feature.js" }
      util.system { "git", "add", "." }
      util.system { "git", "commit", "-m", "some feature" }

      assert.True(gb.is_unmerged("a-new-branch"))
    end)

    it("returns false when feature branch is fully merged into base", function()
      util.system { "git", "checkout", "-b", "a-new-branch" }
      util.system { "git", "reset", "--hard", "origin/master" }
      util.system { "touch", "feature.js" }
      util.system { "git", "add", "." }
      util.system { "git", "commit", "-m", "some feature" }
      util.system { "git", "switch", "master" }
      util.system { "git", "merge", "a-new-branch" }

      assert.False(gb.is_unmerged("a-new-branch"))
    end)

    it("allows specifying alternate base branch", function()
      util.system { "git", "checkout", "-b", "main" }
      util.system { "git", "checkout", "-b", "a-new-branch" }
      util.system { "touch", "feature.js" }
      util.system { "git", "add", "." }
      util.system { "git", "commit", "-m", "some feature" }
      util.system { "git", "switch", "master" }
      util.system { "git", "merge", "a-new-branch" }

      assert.True(gb.is_unmerged("a-new-branch", "main"))
      assert.False(gb.is_unmerged("a-new-branch", "master"))
    end)
  end)

  describe("#delete", function()
    before_each(function()
      git_harness.prepare_repository()
      neogit.reset()
    end)

    describe("when branch is unmerged", function()
      before_each(function()
        util.system { "git", "checkout", "-b", "a-new-branch" }
        util.system { "git", "reset", "--hard", "origin/master" }
        util.system { "touch", "feature.js" }
        util.system { "git", "add", "." }
        util.system { "git", "commit", "-m", "some feature" }
        util.system { "git", "switch", "master" }
      end)

      -- These two tests seem to have a race condition where `input.confirmed` isn't set properly
      pending("prompts user for confirmation (yes) and deletes branch", function()
        input.confirmed = true

        assert.True(gb.delete("a-new-branch"))
        assert.False(vim.tbl_contains(gb.get_local_branches(true), "a-new-branch"))
      end)

      pending("prompts user for confirmation (no) and doesn't delete branch", function()
        input.confirmed = false

        assert.False(gb.delete("a-new-branch"))
        assert.True(vim.tbl_contains(gb.get_local_branches(true), "a-new-branch"))
      end)
    end)

    describe("when branch is merged", function()
      it("deletes branch", function()
        util.system { "git", "branch", "a-new-branch" }

        assert.True(gb.delete("a-new-branch"))
        assert.False(vim.tbl_contains(gb.get_local_branches(true), "a-new-branch"))
      end)
    end)
  end)

  describe("recent branches", function()
    before_each(function()
      git_harness.prepare_repository()
      -- neogit.reset()
    end)

    it(
      "lists branches based on how recently they were checked out, excluding current & deduplicated",
      function()
        util.system { "git", "checkout", "-b", "first" }
        util.system { "git", "branch", "never-checked-out" }
        util.system { "git", "checkout", "-b", "second" }
        util.system { "git", "checkout", "-b", "third" }
        util.system { "git", "switch", "master" }
        util.system { "git", "switch", "second-branch" }
        util.system { "git", "switch", "master" }
        util.system { "git", "switch", "second-branch" }

        local branches_detected = gb.get_recent_local_branches()
        local branches = {
          "master",
          "third",
          "second",
          "first",
        }

        assert.are.same(branches, branches_detected)
      end
    )
  end)

  describe("local branches", function()
    local branches = {}

    local function setup_local_git_branches()
      branches = {
        "test-branch",
        "tester",
        "test/some-issue",
        "num-branch=123",
        "deeply/nested/branch/name",
      }

      for _, branch in ipairs(branches) do
        vim.system({ "git", "branch", branch }):wait()
      end

      table.insert(branches, "master")
      table.insert(branches, "second-branch")
    end

    before_each(function()
      git_harness.prepare_repository()
      -- neogit.reset()
      setup_local_git_branches()
    end)

    it("properly detects all local branches", function()
      local branches_detected = gb.get_local_branches(true)
      assert.True(neogit_util.lists_equal(branches, branches_detected))
    end)

    it("properly detects all branches but the current branch", function()
      vim.fn.system("git checkout master")
      if vim.v.shell_error ~= 0 then
        error("Failed to checkout master branch!")
      end
      neogit_util.remove_item_from_table(branches, "master")

      local branches_detected = gb.get_local_branches(false)
      assert.True(neogit_util.lists_equal(branches, branches_detected))
    end)
  end)
end)
