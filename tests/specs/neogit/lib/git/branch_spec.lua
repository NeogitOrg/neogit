local gb = require("neogit.lib.git.branch")
local status = require("neogit.status")
local plenary_async = require("plenary.async")
local git_harness = require("tests.util.git_harness")
local util = require("tests.util.util")

describe("git branch lib", function()
  describe("local branches", function()
    local branches = {}

    before_each(function()
      git_harness.prepare_repository()
      plenary_async.util.block_on(status.reset)

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

      require("neogit").setup()
    end)

    it("properly detects all local branches", function()
      local branches_detected = gb.get_local_branches(true)
      print("Branches:\n  " .. vim.inspect(branches))
      print("Branches Detected:\n  " .. vim.inspect(branches_detected))
      assert.True(util.lists_equal(branches, branches_detected))
    end)

    it("properly detects all branches but the current branch", function()
      vim.fn.system("git checkout master")
      if vim.v.shell_error ~= 0 then
        error("Failed to checkout master branch!")
      end
      util.remove_item_from_table(branches, "master")

      local branches_detected = gb.get_local_branches(false)
      print("Branches:\n  " .. vim.inspect(branches))
      print("Branches Detected:\n  " .. vim.inspect(branches_detected))
      assert.True(util.lists_equal(branches, branches_detected))
    end)
  end)
end)
