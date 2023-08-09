local gb = require("neogit.lib.git.branch")
local status = require("neogit.status")
local plenary_async = require("plenary.async")
local git_harness = require("tests.util.git_harness")
local neogit_util = require("neogit.lib.util")
local util = require("tests.util.util")
local input = require("tests.mocks.input")

describe("lib.git.branch", function()
  describe("#exists", function()
    before_each(function()
      git_harness.prepare_repository()
      plenary_async.util.block_on(status.reset)
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
      plenary_async.util.block_on(status.reset)
    end)

    it("returns true when feature branch has commits base branch doesn't", function()
      util.system([[
          git checkout -b a-new-branch
          git reset --hard origin/master
          touch feature.js
          git add .
          git commit -m 'some feature'
        ]])

      assert.True(gb.is_unmerged("a-new-branch"))
    end)

    it("returns false when feature branch is fully merged into base", function()
      util.system([[
          git checkout -b a-new-branch
          git reset --hard origin/master
          touch feature.js
          git add .
          git commit -m 'some feature'
          git switch master
          git merge a-new-branch
        ]])

      assert.False(gb.is_unmerged("a-new-branch"))
    end)

    it("allows specifying alternate base branch", function()
      util.system([[
          git checkout -b main
          git checkout -b a-new-branch
          touch feature.js
          git add .
          git commit -m 'some feature'
          git switch master
          git merge a-new-branch
        ]])

      assert.True(gb.is_unmerged("a-new-branch", "main"))
      assert.False(gb.is_unmerged("a-new-branch", "master"))
    end)
  end)

  describe("#delete", function()
    before_each(function()
      git_harness.prepare_repository()
      plenary_async.util.block_on(status.reset)
    end)

    describe("when branch is unmerged", function()
      before_each(function()
        util.system([[
          git checkout -b a-new-branch
          git reset --hard origin/master
          touch feature.js
          git add .
          git commit -m 'some feature'
          git switch master
        ]])
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
        util.system("git branch a-new-branch")

        assert.True(gb.delete("a-new-branch"))
        assert.False(vim.tbl_contains(gb.get_local_branches(true), "a-new-branch"))
      end)
    end)
  end)

  describe("recent branches", function()
    before_each(function()
      git_harness.prepare_repository()
      plenary_async.util.block_on(status.reset)
    end)

    it(
      "lists branches based on how recently they were checked out, excluding current & deduplicated",
      function()
        util.system([[
        git checkout -b first
        git branch never-checked-out
        git checkout -b second
        git checkout -b third
        git switch master
        git switch second-branch
        git switch master
        git switch second-branch
      ]])

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
        vim.fn.system("git branch " .. branch)

        if vim.v.shell_error ~= 0 then
          error("Unable to create testing branch: " .. branch)
        end
      end

      table.insert(branches, "master")
      table.insert(branches, "second-branch")
    end

    before_each(function()
      git_harness.prepare_repository()
      plenary_async.util.block_on(status.reset)
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
