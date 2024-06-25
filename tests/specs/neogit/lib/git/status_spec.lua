local neogit = require("neogit")
local git_harness = require("tests.util.git_harness")
local util = require("tests.util.util")

local subject = require("neogit.lib.git.status")

neogit.setup {}

describe("lib.git.status", function()
  before_each(function()
    git_harness.prepare_repository()
    -- plenary_async.util.block_on(neogit.reset)
  end)

  describe("#anything_staged", function()
    -- it("returns true when there are staged items", function()
    --   util.system("git add --all")
    --   plenary_async.util.block_on(neogit.refresh)
    --
    --   assert.True(subject.anything_staged())
    -- end)

    it("returns false when there are no staged items", function()
      util.system { "git", "reset" }
      neogit.refresh()

      assert.False(subject.anything_staged())
    end)
  end)

  describe("#anything_unstaged", function()
    -- it("returns true when there are unstaged items", function()
    --   util.system("git reset")
    --   plenary_async.util.block_on(neogit.refresh)
    --
    --   assert.True(subject.anything_unstaged())
    -- end)

    it("returns false when there are no unstaged items", function()
      util.system { "git", "add", "--all" }
      neogit.refresh()

      assert.False(subject.anything_unstaged())
    end)
  end)
end)
