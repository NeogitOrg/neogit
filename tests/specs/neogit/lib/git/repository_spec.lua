local eq = assert.are.same
local git_harness = require("tests.util.git_harness")
local in_prepared_repo = git_harness.in_prepared_repo
local git_repo = require("neogit.lib.git.repository")

describe("lib.git.instance", function()
  describe("getting instance", function()
    it(
      "creates cached git instance and returns it",
      in_prepared_repo(function(root_dir)
        local dir1 = git_repo.instance(root_dir).worktree_root
        local dir2 = git_repo.instance().worktree_root
        eq(dir1, dir2)
      end)
    )
  end)
end)
