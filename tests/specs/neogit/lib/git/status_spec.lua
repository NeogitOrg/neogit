local status = require("neogit.status")
local plenary_async = require("plenary.async")
local git_harness = require("tests.util.git_harness")
local util = require("tests.util.util")

local subject = require("neogit.lib.git.status")

describe("lib.git.status", function()
  before_each(function()
    git_harness.prepare_repository()
    plenary_async.util.block_on(status.reset)
  end)

  describe("#anything_staged", function()
    it("returns true when there are staged items", function()
      util.system("git add --all")
      plenary_async.util.block_on(status.reset)

      assert.True(subject.anything_staged())
    end)

    it("returns false when there are no staged items", function()
      util.system("git reset")
      plenary_async.util.block_on(status.reset)

      assert.False(subject.anything_staged())
    end)
  end)

  describe("#anything_unstaged", function()
    it("returns true when there are unstaged items", function()
      util.system("git reset")
      plenary_async.util.block_on(status.reset)

      assert.True(subject.anything_unstaged())
    end)

    it("returns false when there are no unstaged items", function()
      util.system("git add --all")
      plenary_async.util.block_on(status.reset)

      assert.False(subject.anything_unstaged())
    end)
  end)
end)
