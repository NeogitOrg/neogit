local status = require("neogit.status")
local plenary_async = require("plenary.async")
local git_harness = require("tests.util.git_harness")
local util = require("tests.util.util")

local subject = require("neogit.lib.git.log")

describe("lib.git.log", function()
  before_each(function()
    git_harness.prepare_repository()
    plenary_async.util.block_on(status.reset)
  end)

  describe("#is_ancestor", function()
    it("returns true when first ref is ancestor of second", function()
      assert.True(subject.is_ancestor(git_harness.get_git_rev("HEAD~1"), "HEAD"))
    end)

    it("returns false when first ref is not ancestor of second", function()
      util.system([[
        git checkout -b new-branch
        git commit --allow-empty -m "empty commit"
      ]])

      local commit = git_harness.get_git_rev("HEAD")

      util.system("git switch master")

      assert.False(subject.is_ancestor(commit, "HEAD"))
    end)
  end)
end)
